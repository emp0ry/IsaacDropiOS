#import "ISDNativeInput.h"
#import "ISDHost.h"
#include "ISDDropPolicy.hpp"
#include "ISDRestartPolicy.hpp"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#include <array>
#include <algorithm>
#include <atomic>
#include <cstring>
#include <vector>

namespace {
constexpr const char *SupportedUUID = "F4357753-A25F-30EE-BACF-63709F902895";
constexpr uintptr_t GameGlobal = 0xac3b90;
constexpr uintptr_t IOSVTable = 0xa92d88;
constexpr uintptr_t PressedOffset = 0x8a7fec;
constexpr uintptr_t TriggeredOffset = 0x8a8098;
constexpr uintptr_t ValueOffset = 0x8a8150;
constexpr uintptr_t InputBlockedOffset = 0x5049c4;
constexpr uintptr_t RefreshActiveHUDOffset = 0x6ebd10;
constexpr uintptr_t SwapActiveSlotsOffset = 0x5390f8;
constexpr uint32_t TouchControllerID = 0x0010dead;
constexpr int DropAction = 11;
constexpr uintptr_t ManagerGlobal = 0xac2428;
constexpr uintptr_t QueueRestartOffset = 0x672568;
constexpr uintptr_t SeedsCopyOffset = 0x56fc54;
constexpr uintptr_t SeedsDestroyOffset = 0x56fcd4;
constexpr uintptr_t CounterAddOffset = 0x701e28;
using BoolQuery = bool (*)(void *,int);
using ValueQuery = float (*)(void *,int);
static BoolQuery OriginalPressed, OriginalTriggered;
static ValueQuery OriginalValue;
static std::atomic<bool> Available{false};
static __weak CADisplayLink *NativeLink;
static IsaacDrop::Press Gesture;
// Two Itanium ABI prefix words (offset-to-top and RTTI), then 39 native methods.
static std::array<uintptr_t,41> ShadowTable{};
static uintptr_t HookedDevice = 0;

static bool Read(uintptr_t address, void *bytes, size_t count) {
    vm_size_t copied = 0;
    return address && bytes && count && vm_read_overwrite(mach_task_self(),address,count,
        reinterpret_cast<vm_address_t>(bytes),&copied) == KERN_SUCCESS && copied == count;
}

static bool Writable(uintptr_t address, size_t length) {
    if (!address || !length) return false;
    vm_address_t region = address; vm_size_t size = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info),&count,&object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    return kr == KERN_SUCCESS && region <= address && address-region <= size &&
        length <= size-(address-region) &&
        (info.protection & (VM_PROT_READ|VM_PROT_WRITE)) == (VM_PROT_READ|VM_PROT_WRITE) &&
        !(info.protection & VM_PROT_EXECUTE);
}

static bool MatchWords(uintptr_t address, std::initializer_list<uint32_t> expected) {
    std::array<uint32_t,8> actual{};
    if (expected.size() > actual.size() || !Read(address,actual.data(),expected.size()*4)) return false;
    return std::equal(expected.begin(),expected.end(),actual.begin());
}

static bool SwitchCodeMatches(uintptr_t image) {
    // Verify the actual native short-Drop branch as well as every callee used.
    // DeviceiOS (0x0010dead) bypasses this branch entirely, which is why merely
    // supplying ACTION_DROP cannot switch its D Infinity.
    return MatchWords(image+0x52adb0,{0xb9596668,0x7107a51f,0x54000261,0x79f2fe68,0x11000508}) &&
        MatchWords(image+0x52add8,{0x1b0aa137,0x7932fe77}) &&
        MatchWords(image+InputBlockedOffset,{0x39470808,0x340001a8,0xb9573808}) &&
        MatchWords(image+RefreshActiveHUDOffset,{0x91096008,0x52800109,0xd109610a,0xf940014a}) &&
        MatchWords(image+SwapActiveSlotsOffset,{0xd10103ff,0xa9024ff4,0xa9037bfd,0x9100c3fd});
}

static bool RestartCodeMatches(uintptr_t image) {
    // Native Game update fade mode 5 is the controller-hold restart path.
    // It copies Seeds, resets native counters, then queues a fresh run. Modes
    // 1/2/3/4 and the R Key collectible have different semantics; do not use them.
    return MatchWords(image+0x88ddb0,{0x91409688,0x91310100,0x52800001,0x97f131ee}) &&
        MatchWords(image+0x88de30,{0xaa1503e0,0x52800002,0x52800023,0x97f791cb}) &&
        MatchWords(image+QueueRestartOffset,{0xd10283ff,0xa90757f6,0xa9084ff4,0xa9097bfd}) &&
        MatchWords(image+SeedsCopyOffset,{0x17ffffcd}) &&
        MatchWords(image+0x56fb88,{0xa9bc5ff8,0xa90157f6,0xa9024ff4,0xa9037bfd}) &&
        MatchWords(image+SeedsDestroyOffset,{0xa9be4ff4,0xa9017bfd,0x910043fd,0xaa0003f3}) &&
        MatchWords(image+CounterAddOffset,{0xa9ba6ffc,0xa90167fa,0xa9025ff8,0xa90357f6}) &&
        MatchWords(image+0x572488,{0xaa0103e8,0x52800001,0x35000088,0x39400008}) &&
        MatchWords(image+0x67155c,{0x2940db15,0x9147da68,0x912d4101,0x910023e0});
}

static NSString *UUID(const mach_header_64 *header) {
    if (!header || header->magic != MH_MAGIC_64 || header->sizeofcmds > 1024*1024 || header->ncmds > 4096) return nil;
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header+1);
    const uint8_t *end = cursor+header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        if (cursor > end || size_t(end-cursor) < sizeof(load_command)) break;
        const load_command *cmd = reinterpret_cast<const load_command *>(cursor);
        if (cmd->cmdsize < sizeof(load_command) || size_t(end-cursor) < cmd->cmdsize) break;
        if (cmd->cmd == LC_UUID && cmd->cmdsize >= sizeof(uuid_command)) {
            const uuid_command *uuid = reinterpret_cast<const uuid_command *>(cursor);
            return [[NSUUID alloc] initWithUUIDBytes:uuid->uuid].UUIDString;
        }
        cursor += cmd->cmdsize;
    }
    return nil;
}

struct Segment { uintptr_t address; size_t size; vm_prot_t protection; };
static std::vector<Segment> Segments(const mach_header_64 *header, intptr_t slide) {
    std::vector<Segment> result;
    const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header+1);
    for (uint32_t index = 0; index < header->ncmds; ++index) {
        const load_command *cmd = reinterpret_cast<const load_command *>(cursor);
        if (cmd->cmd == LC_SEGMENT_64 && cmd->cmdsize >= sizeof(segment_command_64)) {
            const segment_command_64 *seg = reinterpret_cast<const segment_command_64 *>(cursor);
            if ((seg->initprot & VM_PROT_READ) && seg->vmsize && seg->vmsize < 64*1024*1024 &&
                strcmp(seg->segname,"__LINKEDIT") && strcmp(seg->segname,"__PAGEZERO"))
                result.push_back({uintptr_t(seg->vmaddr+slide),size_t(seg->vmsize),seg->initprot});
        }
        cursor += cmd->cmdsize;
    }
    return result;
}

static std::vector<uintptr_t> PlayerVTables(const std::vector<Segment>& segments) {
    const char name[] = "N15IsaacRepentance13Entity_PlayerE";
    uintptr_t typeName = 0;
    for (const auto& seg : segments) {
        if (seg.protection & VM_PROT_WRITE) continue;
        const uint8_t *bytes = reinterpret_cast<const uint8_t *>(seg.address);
        for (size_t off = 0; off+sizeof(name) <= seg.size; ++off)
            if (!memcmp(bytes+off,name,sizeof(name))) { typeName = seg.address+off; break; }
        if (typeName) break;
    }
    if (!typeName) return {};
    std::vector<uintptr_t> types, tables;
    for (const auto& seg : segments) {
        const uintptr_t *bytes = reinterpret_cast<const uintptr_t *>(seg.address);
        for (size_t index = 1; index < seg.size/8; ++index)
            if (bytes[index] == typeName && types.size() < 8) types.push_back(seg.address+8*(index-1));
    }
    for (const auto& seg : segments) {
        const uintptr_t *bytes = reinterpret_cast<const uintptr_t *>(seg.address);
        for (size_t index = 1; index+1 < seg.size/8; ++index)
            for (uintptr_t type : types)
                if (bytes[index] == type && bytes[index-1] == 0 && bytes[index+1] && tables.size() < 8)
                    tables.push_back(seg.address+8*(index+1));
    }
    return tables;
}

struct Span { uintptr_t begin, end, capacity; };
static bool LivePlayerVector(uintptr_t address, const std::vector<uintptr_t>& tables) {
    Span span{};
    if (!Read(address,&span,sizeof(span)) || !span.begin || span.begin%8 || span.end <= span.begin ||
        span.capacity < span.end || span.capacity-span.begin > 64*8 || (span.end-span.begin)%8 ||
        (span.end-span.begin)/8 > 8) return false;
    std::array<uintptr_t,8> players{};
    size_t count = (span.end-span.begin)/8;
    if (!Read(span.begin,players.data(),count*8)) return false;
    for (size_t i = 0; i < count; ++i) {
        uintptr_t table = 0;
        int32_t entity[2]{};
        if (!Read(players[i],&table,8) || !Read(players[i]+0x38,entity,sizeof(entity)) ||
            entity[0] != 1 || entity[1] != 0) return false;
        bool valid = false;
        for (uintptr_t expected : tables) if (table == expected) valid = true;
        if (!valid) return false;
    }
    Span after{};
    return Read(address,&after,sizeof(after)) && !memcmp(&span,&after,sizeof(span));
}

static IsaacDrop::Sample Synthetic() {
    if (!Available.load(std::memory_order_acquire) || !NSThread.isMainThread) return {};
    CADisplayLink *link = NativeLink;
    IsaacDrop::Sample sample = Gesture.Read(link.timestamp,CACurrentMediaTime(),link != nil &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        CACurrentMediaTime()-link.timestamp < 1);
    static double loggedFrame = 0;
    if (sample.triggered && link.timestamp != loggedFrame) {
        loggedFrame = link.timestamp;
        ISDLog(@"native Drop pulse sampled (one native frame)");
    }
    return sample;
}

static bool Pressed(void *device, int action) {
    bool original = OriginalPressed(device,action);
    return action == DropAction ? (Synthetic().pressed || original) : original;
}
static bool Triggered(void *device, int action) {
    bool original = OriginalTriggered(device,action);
    return action == DropAction ? (Synthetic().triggered || original) : original;
}
static float Value(void *device, int action) {
    float original = OriginalValue(device,action);
    return action == DropAction && Synthetic().pressed ? 1.f : original;
}

static bool ValidTouchDevice(uintptr_t address, uintptr_t nativeTable) {
    std::array<uint8_t,0xe0> bytes{};
    if (!Read(address,bytes.data(),bytes.size())) return false;
    uintptr_t table = 0, current = 0, previous = 0;
    uint32_t id = 0, actions = 0;
    memcpy(&table,bytes.data(),8); memcpy(&id,bytes.data()+8,4);
    memcpy(&actions,bytes.data()+0x1c,4);
    memcpy(&current,bytes.data()+0xd0,8); memcpy(&previous,bytes.data()+0xd8,8);
    // The supported DeviceiOS initializer sets the unique ID to 0x0010dead.
    if (table != nativeTable || id != TouchControllerID || bytes[0xd] > 1 || bytes[0x28] != 1 ||
        actions <= DropAction || actions > 64 || !current || !previous || current == previous) return false;
    std::array<float,64> values{};
    for (uintptr_t pointer : {current,previous}) {
        if (!Read(pointer,values.data(),actions*sizeof(float))) return false;
        for (uint32_t i = 0; i < actions; ++i)
            if (!std::isfinite(values[i]) || std::fabs(values[i]) > 2) return false;
    }
    return true;
}

static uintptr_t FindTouchDevice(uintptr_t nativeTable) {
    vm_address_t address = 0;
    size_t scanned = 0;
    uintptr_t found = 0;
    constexpr size_t Chunk = 1024*1024, Limit = size_t(2)*1024*1024*1024;
    std::vector<uint8_t> bytes(Chunk);
    while (scanned < Limit) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info{};
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        kern_return_t kr = vm_region_64(mach_task_self(),&address,&size,VM_REGION_BASIC_INFO_64,
            reinterpret_cast<vm_region_info_t>(&info),&count,&object);
        if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
        if (kr != KERN_SUCCESS || !size || address+size <= address) break;
        if ((info.protection & (VM_PROT_READ|VM_PROT_WRITE)) == (VM_PROT_READ|VM_PROT_WRITE) &&
            !(info.protection & VM_PROT_EXECUTE)) {
            for (size_t offset = 0; offset < size && scanned < Limit; offset += Chunk) {
                size_t length = MIN(size-offset,Chunk);
                scanned += length;
                if (!Read(address+offset,bytes.data(),length)) continue;
                for (size_t i = 0; i+8 <= length; i += 8) {
                    uintptr_t table = 0;
                    memcpy(&table,bytes.data()+i,8);
                    if (table != nativeTable || !ValidTouchDevice(address+offset+i,nativeTable)) continue;
                    if (found) { ISDLog(@"ambiguous native touch devices; input disabled"); return 0; }
                    found = address+offset+i;
                }
            }
        }
        address += size;
    }
    return found;
}

// Preserve the complete ABI table and RTTI in our own ordinary writable data.
// Only the validated writable input object's vptr changes. Protected constants,
// instructions, other objects, and physical controller tables remain untouched.
static bool Install(uintptr_t image, const std::vector<Segment>& segments, uintptr_t device) {
    std::array<uintptr_t,41> original{};
    uintptr_t nativeTable = image+IOSVTable;
    if (!Read(nativeTable-16,original.data(),sizeof(original)) || original[0] != 0 || !original[1]) return false;
    std::array<uintptr_t,3> expected{image+PressedOffset,image+TriggeredOffset,image+ValueOffset};
    const uint32_t prologues[]{0xa9bd57f6,0xa9bd57f6,0x6dbc23e9};
    for (size_t i = 0; i < 3; ++i) {
        uint32_t word = 0;
        if (original[2+9+i] != expected[i] || !Read(expected[i],&word,4) || word != prologues[i]) return false;
    }
    for (size_t i = 2; i < original.size(); ++i) {
        bool executable = false;
        for (const auto& seg : segments)
            if ((seg.protection & VM_PROT_EXECUTE) && original[i] >= seg.address &&
                original[i]-seg.address < seg.size) executable = true;
        if (!executable) return false;
    }
    if (!device || !ValidTouchDevice(device,nativeTable)) return false;
    vm_address_t region = device; vm_size_t size = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info),&count,&object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    if (kr != KERN_SUCCESS || region > device || device-region+8 > size ||
        (info.protection & (VM_PROT_READ|VM_PROT_WRITE)) != (VM_PROT_READ|VM_PROT_WRITE) ||
        (info.protection & VM_PROT_EXECUTE)) return false;
    ShadowTable = original;
    OriginalPressed = reinterpret_cast<BoolQuery>(expected[0]);
    OriginalTriggered = reinterpret_cast<BoolQuery>(expected[1]);
    OriginalValue = reinterpret_cast<ValueQuery>(expected[2]);
    ShadowTable[2+9] = reinterpret_cast<uintptr_t>(&Pressed);
    ShadowTable[2+10] = reinterpret_cast<uintptr_t>(&Triggered);
    ShadowTable[2+11] = reinterpret_cast<uintptr_t>(&Value);
    uintptr_t expectedTable = nativeTable;
    if (!__atomic_compare_exchange_n(reinterpret_cast<uintptr_t *>(device),&expectedTable,
            reinterpret_cast<uintptr_t>(ShadowTable.data()+2),false,__ATOMIC_RELEASE,__ATOMIC_RELAXED)) return false;
    HookedDevice = device;
    return true;
}
}

@implementation ISDNativeInput {
    const mach_header_64 *_header;
    intptr_t _slide;
    std::vector<Segment> _segments;
    std::vector<uintptr_t> _playerTables;
    size_t _playerOffset;
    uintptr_t _lastGame;
    double _lastScan;
    BOOL _installed;
    BOOL _switchReady;
    BOOL _restartReady;
    IsaacDrop::RestartHold _restartHold;
    BOOL _searching, _searchReady;
    uintptr_t _candidate;
    NSUInteger _searchAttempts;
    double _retryAfter;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _playerOffset = SIZE_MAX;
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const mach_header_64 *header = reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(i));
        if ([UUID(header) isEqualToString:@(SupportedUUID)]) {
            _header = header; _slide = _dyld_get_image_vmaddr_slide(i); break;
        }
    }
    if (_header) {
        _segments = Segments(_header,_slide);
        _playerTables = PlayerVTables(_segments);
        _switchReady = SwitchCodeMatches(reinterpret_cast<uintptr_t>(_header));
        _restartReady = RestartCodeMatches(reinterpret_cast<uintptr_t>(_header));
        ISDLog(@"D Infinity touch-switch code validation %@",_switchReady ? @"passed" : @"rejected");
        ISDLog(@"native fresh-run restart code validation %@",_restartReady ? @"passed" : @"rejected");
    }
    return self;
}
- (BOOL)supported { return _header && !_playerTables.empty(); }
- (BOOL)installed { return _installed; }
- (BOOL)installWithDisplayLink:(CADisplayLink *)link {
    if (!self.supported || !NSThread.isMainThread) return NO;
    NativeLink = link;
    if (_installed) {
        uintptr_t table = 0;
        if (Read(HookedDevice,&table,8) && table == reinterpret_cast<uintptr_t>(ShadowTable.data()+2)) return YES;
        [self cancel]; _installed = NO;
    }
    if (_searchReady) {
        _searchReady = NO;
        _installed = Install(reinterpret_cast<uintptr_t>(_header),_segments,_candidate);
        ISDLog(@"native Drop instance adapter %@; no page protection changes",_installed ? @"installed" : @"rejected");
        _retryAfter = CACurrentMediaTime()+5;
        if (_installed) return YES;
    }
    if (!_searching && _searchAttempts < 3 && CACurrentMediaTime() >= _retryAfter) {
        _searching = YES; ++_searchAttempts;
        uintptr_t table = reinterpret_cast<uintptr_t>(_header)+IOSVTable;
        // Read-only discovery can traverse large randomized allocator regions.
        // Never perform that scan on the game's UI/render thread.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
            uintptr_t candidate = FindTouchDevice(table);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_searching = NO; self->_searchReady = YES; self->_candidate = candidate;
            });
        });
    }
    return NO;
}
- (BOOL)gameplayAvailable {
    if (!_installed || !NSThread.isMainThread) return NO;
    uintptr_t game = 0, room = 0; int32_t pause = -1; uint32_t seed = 0;
    if (!Read(reinterpret_cast<uintptr_t>(_header)+GameGlobal,&game,8) || !game ||
        !Read(game+0x21550,&room,8) || !room || !Read(game+0x25d44,&seed,4) || !seed ||
        !Read(game+0x10dfd8,&pause,4) || pause != 0) return NO;
    if (_lastGame != game) { _lastGame = game; _playerOffset = SIZE_MAX; }
    if (_playerOffset != SIZE_MAX) return LivePlayerVector(game+_playerOffset,_playerTables);
    double now = CACurrentMediaTime();
    if (now-_lastScan < 1) return NO;
    _lastScan = now;
    vm_address_t region = game; vm_size_t size = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info),&count,&object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    if (kr != KERN_SUCCESS || region > game || !(info.protection & VM_PROT_READ) || size <= game-region) return NO;
    size_t length = MIN(size-(game-region),size_t(512*1024));
    std::vector<uint8_t> bytes(length);
    if (!Read(game,bytes.data(),bytes.size())) return NO;
    for (size_t offset = 0; offset+sizeof(Span) <= length; offset += 8) {
        Span span{}; memcpy(&span,bytes.data()+offset,sizeof(span));
        if (!span.begin || span.end <= span.begin || span.capacity < span.end ||
            span.end-span.begin > 8*8 || (span.end-span.begin)%8) continue;
        if (LivePlayerVector(game+offset,_playerTables)) {
            _playerOffset = offset;
            ISDLog(@"live player vector validated; touch zone enabled only in unpaused runs");
            return YES;
        }
    }
    return NO;
}
- (void)setAvailable:(BOOL)available {
    Available.store(available,std::memory_order_release);
    if (!available) Gesture.Cancel();
}
- (void)press {
    if (![self gameplayAvailable]) { [self cancel]; return; }
    if (!Gesture.Begin(CACurrentMediaTime())) return;
    [self switchTouchDInfinity];
    ISDLog(@"Drop touch down");
}
- (void)switchTouchDInfinity {
    if (!_switchReady || !Available.load(std::memory_order_acquire) ||
        ![self gameplayAvailable] || _playerOffset == SIZE_MAX) return;
    uintptr_t image = reinterpret_cast<uintptr_t>(_header), game = 0;
    Span players{};
    if (!Read(image+GameGlobal,&game,8) || game != _lastGame ||
        !LivePlayerVector(game+_playerOffset,_playerTables) ||
        !Read(game+_playerOffset,&players,sizeof(players))) return;
    for (uintptr_t entry = players.begin; entry < players.end; entry += 8) {
        uintptr_t player = 0;
        uint32_t controller = 0, item = 0, blocked = 0;
        uint8_t disabled = 0;
        int16_t mode = -1, next = -1;
        if (!Read(entry,&player,8) || !Read(player+0x19ec,&controller,4) ||
            controller != TouchControllerID) continue;
        // Only the touch-controlled main active slot needs this adapter.
        // Physical keyboard/gamepad players already take the native branch.
        if (!Read(player+0x1964,&item,4) || item != 489 ||
            !Read(player+0x19d4,&blocked,4) || blocked ||
            !Read(player+0x284c,&disabled,1) || disabled ||
            !Read(player+0x197e,&mode,2) || !IsaacDrop::NextDInfinityMode(mode,next) ||
            !Writable(player,0x284d) || !Writable(game+0x47fe0,8*0x918)) return;
        using BlockedQuery = bool (*)(void *);
        if (reinterpret_cast<BlockedQuery>(image+InputBlockedOffset)(reinterpret_cast<void *>(player))) return;
        // Same 16-bit mode transition and HUD invalidation as native Ctrl.
        // Never use the active item, reroll anything, change charge, or edit saves.
        int16_t expected = mode;
        if (!__atomic_compare_exchange_n(reinterpret_cast<int16_t *>(player+0x197e),&expected,
                next,false,__ATOMIC_RELAXED,__ATOMIC_RELAXED)) return;
        using HUDRefresh = void (*)(void *,void *,int);
        reinterpret_cast<HUDRefresh>(image+RefreshActiveHUDOffset)(
            reinterpret_cast<void *>(game+0x47fe0),reinterpret_cast<void *>(player),0);
        // Native Ctrl wraps D100 -> D1 and then switches the Schoolbag slot.
        // The native helper is a no-op when there is no second active item.
        if (next == 0) {
            using SwapSlots = void (*)(void *);
            reinterpret_cast<SwapSlots>(image+SwapActiveSlotsOffset)(reinterpret_cast<void *>(player));
        }
        ISDLog(@"D Infinity touch switch %d -> %d; native HUD refreshed",int(mode),int(next));
        return;
    }
}
- (void)releasePress { Gesture.End(); ISDLog(@"Drop touch up"); }
- (void)cancel { Available.store(false,std::memory_order_release); Gesture.Cancel(); [self cancelRestart]; }

- (uintptr_t)restartIdentity {
    uintptr_t game = 0; uint32_t seed = 0;
    if (!_header || !Read(reinterpret_cast<uintptr_t>(_header)+GameGlobal,&game,8) ||
        !Read(game+0x25d44,&seed,4) || !seed) return 0;
    return (game >> 4) ^ (uintptr_t(seed) << 32);
}
- (BOOL)restartAvailable {
    if (!_restartReady || ![self gameplayAvailable]) return NO;
    CADisplayLink *link = NativeLink;
    if (!link || CACurrentMediaTime()-link.timestamp > .25) return NO;
    uintptr_t image = reinterpret_cast<uintptr_t>(_header), manager = 0, game = 0;
    uint32_t state = 0, restriction = 0; uint8_t pending = 1;
    float fade = 1;
    if (!Read(image+GameGlobal,&game,8) || game != _lastGame ||
        !Read(image+ManagerGlobal,&manager,8) || !manager ||
        !Read(manager+0x204c0,&state,4) || state != 2 ||
        !Read(manager+0x1f6b40,&pending,1) || pending ||
        !Read(game+0x1cf444,&fade,4) || !std::isfinite(fade) || fade != 0 ||
        !Read(game+0x1cf4c0,&restriction,4) || restriction) return NO;
    Span players{}; uintptr_t player = 0; uint32_t character = UINT32_MAX;
    int32_t edenTokens = 0;
    if (!Read(game+_playerOffset,&players,sizeof(players)) || !Read(players.begin,&player,8) ||
        !Read(player+0x1738,&character,4) || character > 40 ||
        !Read(manager+0x207cc,&edenTokens,4)) return NO;
    // The native restart-input path blocks Eden variants without a token.
    return !((character == 9 || character == 30) && edenTokens <= 0);
}
- (BOOL)restartDown:(unsigned)source {
    BOOL available = [self restartAvailable];
    BOOL accepted = _restartHold.Down(source,CACurrentMediaTime(),[self restartIdentity],available);
    if (accepted) ISDLog(@"restart hold began (source %u)",source);
    return accepted;
}
- (void)restartUp:(unsigned)source { _restartHold.Up(source); }
- (void)cancelRestart { _restartHold.Cancel(); }
- (BOOL)restartTransitionPending { return _restartHold.TransitionPending(); }
- (BOOL)restartContextAvailable {
    // Do not require a room, ready input or a completed fade here: those may
    // disappear during our own queued restart. Actual pause/menu state must
    // still stop repetition immediately, including during that transition.
    if (!_restartReady || !_installed || !NSThread.isMainThread ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    uintptr_t image = reinterpret_cast<uintptr_t>(_header), game = 0, manager = 0;
    uint32_t state = 0, restriction = 0; int32_t pause = -1;
    return Read(image+ManagerGlobal,&manager,8) && manager &&
        Read(manager+0x204c0,&state,4) && state == 2 &&
        Read(image+GameGlobal,&game,8) && game &&
        Read(game+0x10dfd8,&pause,4) && pause == 0 &&
        Read(game+0x1cf4c0,&restriction,4) && restriction == 0;
}
- (void)pollRestart {
    if (!_restartHold.Poll(CACurrentMediaTime(),[self restartIdentity],
            [self restartAvailable],[self restartContextAvailable])) return;
    // This runs between native frames on the main thread. The native queue is
    // consumed by Manager::Update; never destroy Game from an input callback.
    uintptr_t image = reinterpret_cast<uintptr_t>(_header), manager = 0, game = 0;
    uintptr_t player = 0; Span players{};
    uint32_t character = UINT32_MAX; int32_t counter = 0;
    if (!Read(image+ManagerGlobal,&manager,8) || !Read(image+GameGlobal,&game,8) ||
        !Read(game+_playerOffset,&players,sizeof(players)) || !Read(players.begin,&player,8) ||
        !Read(player+0x1738,&character,4) || !Read(manager+0x207d0,&counter,4) ||
        counter < 0 || !Writable(manager,0x1f6cf0) || !Writable(game+0x25d40,0x70)) return;
    using CopySeeds = void (*)(void *,const void *);
    using DestroySeeds = void (*)(void *);
    using AddCounter = void (*)(void *,uint32_t,int32_t);
    using QueueRestart = void (*)(void *,const void *,int,int);
    // Seeds is a 0x70-byte native C++ object with an owning tree. Its real
    // constructor/destructor are required, not memcpy or a zeroed fake seed.
    alignas(16) std::array<uint8_t,0x70> seeds{};
    reinterpret_cast<CopySeeds>(image+SeedsCopyOffset)(seeds.data(),reinterpret_cast<void *>(game+0x25d40));
    auto add = reinterpret_cast<AddCounter>(image+CounterAddOffset);
    add(reinterpret_cast<void *>(manager+0x204d0),22,-counter);
    if (character == 9 || character == 30) add(reinterpret_cast<void *>(manager+0x204d0),21,-1);
    reinterpret_cast<QueueRestart>(image+QueueRestartOffset)(reinterpret_cast<void *>(manager),seeds.data(),0,1);
    reinterpret_cast<DestroySeeds>(image+SeedsDestroyOffset)(seeds.data());
    _restartHold.Queued(CACurrentMediaTime());
    ISDLog(@"native fresh-run restart queued; 1-second repeat while held; character/difficulty retained");
}
@end
