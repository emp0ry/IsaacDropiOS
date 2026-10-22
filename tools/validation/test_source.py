from pathlib import Path
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

class SourceTests(unittest.TestCase):
    def test_touch_zone(self):
        source = (ROOT / "src/ISDBootstrap.m").read_text()
        self.assertIn("CGRectGetMinX(bounds),CGRectGetMaxY(bounds)-64,72,64", source)
        self.assertIn("self.backgroundColor = UIColor.clearColor", source)
        self.assertIn("self.alpha = 1", source)
        self.assertIn("UIControlEventTouchDown", source)
        self.assertIn("UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit", source)
        self.assertIn("self.zone.hidden = !available", source)
        self.assertNotIn("makeKeyAndVisible", source)
        self.assertNotIn("initWithWindowScene", source)

    def test_native_scope(self):
        source = (ROOT / "src/ISDNativeInput.mm").read_text()
        self.assertIn("constexpr int DropAction = 11", source)
        self.assertIn("action == DropAction", source)
        self.assertIn("original[2+9+i] != expected[i]", source)
        self.assertIn("info.protection & VM_PROT_EXECUTE", source)
        self.assertIn("ShadowTable = original", source)
        self.assertIn("__atomic_compare_exchange_n", source)
        self.assertIn("dispatch_get_global_queue(QOS_CLASS_UTILITY,0)", source)
        self.assertNotIn("vm_protect(", source)
        self.assertNotIn("mprotect(", source)
        self.assertNotIn("MSHook", source)
        self.assertNotIn("/var/jb", source)
        self.assertNotIn("UseActiveItem", source)
        self.assertNotIn("RemoveCollectible", source)

    def test_startup(self):
        source = (ROOT / "src/ISDHost.mm").read_text()
        self.assertIn("viewIfLoaded", source)
        self.assertIn("timestamp <= firstTimestamp", source)
        self.assertNotIn("touchesBegan:", source)
        self.assertNotIn("isKeyWindow", source)

    def test_d_infinity_touch_branch(self):
        source = (ROOT / "src/ISDNativeInput.mm").read_text()
        self.assertIn("SwitchCodeMatches", source)
        self.assertIn("controller != TouchControllerID", source)
        self.assertIn("item != 489", source)
        self.assertIn("player+0x197e", source)
        self.assertIn("NextDInfinityMode(mode,next)", source)
        self.assertIn("if (!Gesture.Begin(CACurrentMediaTime())) return", source)
        self.assertIn("if (next == 0)", source)
        self.assertIn("D Infinity touch switch %d -> %d", source)

    def test_d_infinity_keyboard_is_only_the_short_drop_query(self):
        source = (ROOT / "src/ISDNativeInput.mm").read_text()
        self.assertIn("KeyboardDropCodeMatches", source)
        self.assertIn("N4KAGE5Input14DeviceKeyboardE", source)
        self.assertIn("KeyboardShadow[2+9]", source)
        self.assertNotIn("KeyboardShadow[2+10] =", source)
        self.assertNotIn("KeyboardShadow[2+11] =", source)
        self.assertIn("if (!player) return down", source)
        self.assertIn("if (item != 489) return down", source)
        self.assertIn("controller != deviceID", source)
        self.assertIn("__builtin_frame_address(0)", source)
        self.assertNotIn("__builtin_frame_address(1)", source)

    def test_restart_repeats_keep_only_their_own_transition(self):
        native = (ROOT / "src/ISDNativeInput.mm").read_text()
        bootstrap = (ROOT / "src/ISDBootstrap.m").read_text()
        policy = (ROOT / "include/ISDRestartPolicy.hpp").read_text()
        self.assertIn("Seconds = 1.0", policy)
        self.assertIn("_restartHold.Queued(CACurrentMediaTime())", native)
        self.assertIn("[self restartContextAvailable]", native)
        self.assertIn("restartTransitionPending", bootstrap)
        self.assertIn("[self.input pollRestart]", bootstrap)
        self.assertIn("CGRectGetMidX(bounds)-36,CGRectGetMinY(bounds),72,64", bootstrap)
        self.assertNotIn("1.5 seconds", bootstrap)

    def test_packages(self):
        info = plistlib.loads((ROOT / "livecontainer/Info.plist").read_bytes())
        version = re.search(r"^Version: (.+)$", (ROOT / "package/control").read_text(), re.MULTILINE).group(1)
        self.assertEqual(info["CFBundleShortVersionString"], version)
        self.assertEqual(info["CFBundleExecutable"], "IsaacFixes")
        filt = plistlib.loads((ROOT / "package/IsaacFixes.plist").read_bytes())
        self.assertEqual(filt["Filter"]["Bundles"], ["com.Nicalis.Isaac-iOS"])

    def test_escape_native_menu(self):
        native = (ROOT / "src/ISDNativeInput.mm").read_text()
        keys = (ROOT / "src/ISDRestartKey.m").read_text()
        self.assertIn("PauseCodeMatches", native)
        self.assertIn("PauseEnterOffset = 0x8a1d38", native)
        self.assertIn("PauseLeaveOffset = 0x8a1f08", native)
        self.assertIn("ResumeManagerOffset = 0x670ca8", native)
        self.assertIn("liveRunAvailableAllowPause:YES", native)
        self.assertIn("UIKeyboardHIDUsageKeyboardEscape", keys)
        self.assertIn("escapeHeld", keys)

    def test_planetarium_native_read_only_floor_snapshot(self):
        source = (ROOT / "src/ISDPlanetarium.mm").read_text()
        self.assertIn("GetChance=0x6d03a4", source)
        self.assertIn("(base+IsAvailable)(config,3)", source)
        self.assertLess(source.index("if (!initial && _floor==floor) return YES"),
                        source.index("_base+GetChance)(game)"))
        self.assertIn("IsaacFixes.Planetarium.v1", source)
        self.assertIn("_cache.count>=24", source)
        self.assertIn("_lastNativeFrame==_nativeLink.timestamp", source)
        self.assertIn("!IsaacFixes::PlanetariumUnpaused(pause)", source)
        self.assertLess(source.index("!IsaacFixes::PlanetariumUnpaused(pause)"),
                        source.index("_lastNativeFrame==_nativeLink.timestamp"))
        self.assertLess(source.index("!IsaacFixes::PlanetariumUnpaused(pause)"),
                        source.index("_popup.Advance()"))
        self.assertIn("!Read(game+0x18+0x64,generation)", source)
        self.assertIn("PlanetariumDogmaFlash", source)
        self.assertIn("NoHUD(game)", source)
        self.assertIn("roomType==16 && roomStage==35", source)
        for forbidden in ("vm_write(", "MSHook", "RandomInt", "RandomFloat", "Isaac.Spawn", "makeKeyAndVisible"):
            self.assertNotIn(forbidden, source)

if __name__ == "__main__":
    unittest.main()
