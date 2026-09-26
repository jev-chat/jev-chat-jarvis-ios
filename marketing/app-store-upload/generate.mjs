import { chromium } from "playwright";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";

const root = dirname(fileURLToPath(import.meta.url));
const slides = [
  { name: "01-tones", zh: "每句话，都有分寸", en: "Find the right tone.", accent: "#0879bd" },
  { name: "02-models", zh: "模型由你选择", en: "Choose your model.", accent: "#00866e" },
  { name: "03-home", zh: "三步开启键盘", en: "Set up your keyboard.", accent: "#c66535" },
];

const browser = await chromium.launch({
  headless: true,
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});

try {
  const page = await browser.newPage({ viewport: { width: 1320, height: 2868 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(join(root, "template.html")).href);
  for (const locale of ["zh-Hans", "en"]) {
    await mkdir(join(root, locale), { recursive: true });
    for (const [index, slide] of slides.entries()) {
      const source = pathToFileURL(join(root, "source", locale, `${slide.name}.png`)).href;
      const headline = locale === "en" ? slide.en : slide.zh;
      const dimensions = await page.evaluate(async ({ source, headline, accent, index }) => {
        const image = document.getElementById("app");
        image.src = source;
        await image.decode();
        document.getElementById("headline").textContent = headline;
        document.getElementById("counter").textContent = `${String(index + 1).padStart(2, "0")} / 03`;
        document.getElementById("accent").style.background = accent;
        document.body.classList.toggle("two-line", headline.includes("\n"));
        await document.fonts.ready;
        return [image.naturalWidth, image.naturalHeight];
      }, { source, headline, accent: slide.accent, index });
      if (dimensions[0] !== 1320 || dimensions[1] !== 2868) {
        throw new Error(`${source} is ${dimensions.join("x")}; expected 1320x2868`);
      }
      await page.screenshot({ path: join(root, locale, `${slide.name}.png`) });
      console.log(`${locale}/${slide.name}.png`);
    }
  }
} finally {
  await browser.close();
}
