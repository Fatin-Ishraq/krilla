use std::{fs, path::Path, sync::Arc};

use krilla::{
    geom::{Size, Transform},
    page::PageSettings,
    Document,
};
use krilla_svg::{usvg, FilterCache, SurfaceExt, SvgSettings};

fn export(tree: &Arc<usvg::Tree>, cached: bool) -> Vec<u8> {
    let mut doc = Document::new();
    let mut cache = FilterCache::default();
    let fit = (360.0 / tree.size().width()).min(240.0 / tree.size().height());
    for scale in [1.0, 0.5, 1.0, 0.5] {
        let mut page = doc.start_page_with(PageSettings::from_wh(420.0, 300.0).unwrap());
        let mut surface = page.surface();
        surface.push_transform(&Transform::from_translate(20.0, 20.0));
        let size = Size::from_wh(
            tree.size().width() * fit * scale,
            tree.size().height() * fit * scale,
        )
        .unwrap();
        if cached {
            surface
                .draw_svg_cached(tree, size, SvgSettings::default(), &mut cache)
                .unwrap();
        } else {
            surface
                .draw_svg(tree, size, SvgSettings::default())
                .unwrap();
        }
        surface.pop();
        surface.finish();
        page.finish();
    }
    doc.finish().unwrap()
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    assert_eq!(
        args.len(),
        4,
        "usage: cache-native <repo-assets> <fixtures> <output>"
    );
    let assets = Path::new(&args[1]);
    let fixtures = Path::new(&args[2]);
    let out = Path::new(&args[3]);
    fs::create_dir_all(out).unwrap();
    let mut fonts = usvg::fontdb::Database::new();
    fonts.load_fonts_dir(assets.join("fonts"));
    let options = usvg::Options {
        fontdb: Arc::new(fonts),
        font_family: "Noto Sans".into(),
        ..Default::default()
    };
    let cases = [
        ("blur", fixtures.join("blur.svg")),
        ("plain", fixtures.join("plain.svg")),
        ("compositing", fixtures.join("complex.svg")),
        ("subpixel-detail", fixtures.join("subpixel-detail.svg")),
        (
            "small-filtered-text",
            assets.join("svgs/small_text_with_filter.svg"),
        ),
        (
            "historic-5509-1",
            assets.join("svgs/custom_typst_issue_5509_1.svg"),
        ),
        (
            "historic-5509-2",
            assets.join("svgs/custom_typst_issue_5509_2.svg"),
        ),
        (
            "historic-5509-3",
            assets.join("svgs/custom_typst_issue_5509_3.svg"),
        ),
        (
            "real-matplotlib",
            assets.join("svgs/custom_integration_matplotlib_time_series.svg"),
        ),
        (
            "real-drawio",
            assets.join("svgs/custom_integration_drawio_diagram1.svg"),
        ),
    ];
    for (name, path) in cases {
        let data = fs::read(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
        let tree = Arc::new(usvg::Tree::from_data(&data, &options).unwrap());
        let baseline = export(&tree, false);
        let cached = export(&tree, true);
        fs::write(out.join(format!("{name}-uncached.pdf")), &baseline).unwrap();
        fs::write(out.join(format!("{name}-cached.pdf")), &cached).unwrap();
        assert_eq!(baseline, cached, "PDF bytes changed for {name}");
        println!("{name}: PDF bytes identical, four pages with mixed sizes");
    }
}
