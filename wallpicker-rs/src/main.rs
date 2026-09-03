use gtk4 as gtk;
use gtk4::gdk;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4_layer_shell::{KeyboardMode, Layer, LayerShell};
use std::path::PathBuf;
use std::process::Command;
use std::rc::Rc;
use std::cell::RefCell;

const APP_ID: &str = "dev.local.wallpicker";
const CSS: &str = include_str!("style.css");

fn wallpaper_dir() -> PathBuf {
    let home = std::env::var("HOME").expect("HOME not set");
    PathBuf::from(home).join("Pictures/Wallpapers")
}

fn is_image(path: &std::path::Path) -> bool {
    matches!(
        path.extension()
            .and_then(|e| e.to_str())
            .map(|e| e.to_lowercase()),
        Some(ref e) if ["jpg", "jpeg", "png", "webp", "bmp"].contains(&e.as_str())
    )
}

fn cache_dir() -> PathBuf {
    let home = std::env::var("HOME").expect("HOME not set");
    let dir = PathBuf::from(home).join(".cache/wallpicker");
    let _ = std::fs::create_dir_all(&dir);
    dir
}


fn cached_thumbnail_path(original: &std::path::Path) -> Option<PathBuf> {
    let file_name = original.file_name()?.to_str()?;
    let thumb_path = cache_dir().join(format!("{file_name}.thumb.png"));

    let original_mtime = std::fs::metadata(original).and_then(|m| m.modified()).ok();
    let thumb_mtime = std::fs::metadata(&thumb_path).and_then(|m| m.modified()).ok();

    let needs_regen = match (original_mtime, thumb_mtime) {
        (Some(orig), Some(thumb)) => orig > thumb,
        _ => true,
    };

    if needs_regen {
        let pixbuf = gtk::gdk_pixbuf::Pixbuf::from_file_at_scale(original, 340, 191, true).ok()?;
        pixbuf.savev(&thumb_path, "png", &[]).ok()?;
    }

    Some(thumb_path)
}

fn collect_wallpapers() -> Vec<PathBuf> {
    let dir = wallpaper_dir();
    let mut files: Vec<PathBuf> = std::fs::read_dir(&dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .map(|e| e.path())
                .filter(|p| p.is_file() && is_image(p))
                .collect()
        })
        .unwrap_or_default();
    files.sort();
    files
}

fn set_wallpaper(path: &std::path::Path) {
    let path = path.to_path_buf();
    let _ = Command::new("awww")
        .arg("img")
        .arg(&path)
        .arg("--transition-type")
        .arg("grow")
        .arg("--transition-fps")
        .arg("60")
        .arg("--transition-duration")
        .arg("0.8")
        .arg("--transition-pos")
        .arg("0.5,0.5")
        .spawn();
}

fn build_ui(app: &gtk::Application) {
    let window = gtk::ApplicationWindow::new(app);
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(KeyboardMode::Exclusive);
    window.set_namespace(Some("wallpicker"));

    window.set_default_size(1200, 700);
    window.set_width_request(1200);
    window.set_height_request(700);

    let wallpapers = collect_wallpapers();

    let flow = gtk::FlowBox::new();
    flow.set_valign(gtk::Align::Start);
    flow.set_max_children_per_line(3);
    flow.set_min_children_per_line(3);
    flow.set_selection_mode(gtk::SelectionMode::Single);
    flow.set_row_spacing(16);
    flow.set_column_spacing(16);
    flow.set_homogeneous(true);
    flow.add_css_class("wall-grid");
    flow.set_size_request(1200 - 48, -1);

    let paths: Rc<RefCell<Vec<PathBuf>>> = Rc::new(RefCell::new(wallpapers.clone()));

    for wp in &wallpapers {
        let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
        card.add_css_class("wall-card");

        let picture = match cached_thumbnail_path(wp) {
            Some(thumb) => gtk::Picture::for_filename(&thumb),
            None => gtk::Picture::for_filename(wp),
        };
        picture.set_content_fit(gtk::ContentFit::Contain);
        picture.set_size_request(340, 191);
        picture.add_css_class("wall-thumb");

        let label = gtk::Label::new(
            wp.file_name().and_then(|n| n.to_str()),
        );
        label.add_css_class("wall-label");
        label.set_ellipsize(gtk::pango::EllipsizeMode::Middle);
        label.set_max_width_chars(28);

        card.append(&picture);
        card.append(&label);

        flow.append(&card);
    }

    if let Some(first_child) = flow.child_at_index(0) {
        flow.select_child(&first_child);
    }

    let scrolled = gtk::ScrolledWindow::new();
    scrolled.set_child(Some(&flow));
    scrolled.set_policy(gtk::PolicyType::Never, gtk::PolicyType::Automatic);
    scrolled.set_size_request(1200 - 48, 700 - 48);

    let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
    root.add_css_class("wall-root");
    root.append(&scrolled);

    window.set_child(Some(&root));
    window.add_css_class("wallpicker-window");

    let key_controller = gtk::EventControllerKey::new();
    let win_for_keys = window.clone();
    let flow_for_keys = flow.clone();
    let paths_for_keys = paths.clone();

    key_controller.connect_key_pressed(move |_, keyval, _, _| {
        match keyval {
            gdk::Key::Escape => {
                win_for_keys.close();
                glib::Propagation::Stop
            }
            gdk::Key::Return | gdk::Key::KP_Enter => {
                if let Some(child) = flow_for_keys.selected_children().into_iter().next() {
                    let idx = child.index() as usize;
                    if let Some(path) = paths_for_keys.borrow().get(idx) {
                        set_wallpaper(path);
                    }
                }
                win_for_keys.close();
                glib::Propagation::Stop
            }
            _ => glib::Propagation::Proceed,
        }
    });
    window.add_controller(key_controller);

    let win_for_click = window.clone();
    let paths_for_click = paths.clone();
    flow.connect_child_activated(move |_, child| {
        let idx = child.index() as usize;
        if let Some(path) = paths_for_click.borrow().get(idx) {
            set_wallpaper(path);
        }
        win_for_click.close();
    });

    window.present();
}

fn main() {
    let app = gtk::Application::new(Some(APP_ID), Default::default());

    app.connect_startup(|_| {
        let provider = gtk::CssProvider::new();
        provider.load_from_data(CSS);
        gtk::style_context_add_provider_for_display(
            &gdk::Display::default().expect("no display"),
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    });

    app.connect_activate(build_ui);
    app.run();
}
