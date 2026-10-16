from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[1]

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

    def test_packages(self):
        info = plistlib.loads((ROOT / "livecontainer/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleShortVersionString"], "0.1.1")
        self.assertEqual(info["CFBundleExecutable"], "IsaacDrop")
        filt = plistlib.loads((ROOT / "package/IsaacDrop.plist").read_bytes())
        self.assertEqual(filt["Filter"]["Bundles"], ["com.Nicalis.Isaac-iOS"])

if __name__ == "__main__":
    unittest.main()
