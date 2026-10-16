from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids, self.links, self.assets = [], [], []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            self.ids.append(attributes["id"])
        for key in ("href", "src"):
            if key in attributes:
                self.links.append(attributes[key])
        if "data-asset" in attributes:
            self.assets.append(attributes["data-asset"])


class WebsiteTests(unittest.TestCase):
    def test_links_and_unique_ids(self):
        page = Page((DOCS / "index.html").read_text())
        self.assertEqual(len(page.ids), len(set(page.ids)))
        for link in page.links:
            if link.startswith("#"):
                self.assertIn(link[1:], page.ids)
            elif not urlparse(link).scheme:
                self.assertTrue((DOCS / link).is_file(), link)
        self.assertEqual(set(page.assets), {
            "IsaacDrop.dylib", "IsaacDrop-rootless.deb",
            "IsaacDrop-LiveContainer.framework.zip", "IsaacDrop-Embedded.zip",
            "SHA256SUMS",
        })

    def test_domain_and_compatibility(self):
        text = (DOCS / "index.html").read_text()
        self.assertEqual((DOCS / "CNAME").read_text().strip(), "isaacctrlios.emp0ry.com")
        self.assertIn('rel="canonical" href="https://isaacctrlios.emp0ry.com/"', text)
        self.assertIn("72 × 64", text)
        self.assertIn("bottom-left", text)
        self.assertIn("1.7.9b.J754", text)
        self.assertIn("not yet fully supported", text)
        ET.parse(DOCS / "sitemap.xml")
        ET.parse(DOCS / "favicon.svg")

    def test_release_metadata(self):
        control = (ROOT / "package/control").read_text()
        version = re.search(r"^Version: (.+)$", control, re.MULTILINE).group(1)
        info = plistlib.loads((ROOT / "livecontainer/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleShortVersionString"], version)
        self.assertTrue((DOCS / f"RELEASE_NOTES_v{version}.md").is_file())
        self.assertIn(f"v{version}", (DOCS / "index.html").read_text())
        workflows = list((ROOT / ".github/workflows").glob("*.yml"))
        self.assertEqual(len(workflows), 1)


if __name__ == "__main__":
    unittest.main()
