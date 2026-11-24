//! COSMIC panel applet: fcitx5's current input method as text, EN or あ (another layout: its code, e.g. DE).
//! Left click switches (as Ctrl-Space), right click opens fcitx5's settings. COSMIC's own Input Sources applet
//! shows only the keyboard layout, which stays "en" while Mozc types Japanese.
//! fcitx5 is asked over D-Bus (org.fcitx.Fcitx5 /controller, CurrentInputMethod) a few times a second: it sends
//! no signal when the input method changes.

use cosmic::iced::futures::stream;
use cosmic::iced::{Length, Subscription};
use cosmic::prelude::*;
use cosmic::widget::{self, MouseArea};
use std::time::Duration;

const POLL: Duration = Duration::from_millis(300);

#[zbus::proxy(
    interface = "org.fcitx.Fcitx.Controller1",
    default_service = "org.fcitx.Fcitx5",
    default_path = "/controller"
)]
trait Controller {
    fn current_input_method(&self) -> zbus::Result<String>;
    fn toggle(&self) -> zbus::Result<()>;
}

/// "mozc" -> あ, "keyboard-us" -> EN, "keyboard-de" -> DE, nothing (fcitx5 not running) -> –
fn label(im: &str) -> String {
    match im {
        "" => "–".into(),
        "mozc" | "anthy" | "skk" | "kkc" => "あ".into(),
        "keyboard-us" => "EN".into(),
        _ => im.trim_start_matches("keyboard-").chars().take(2).collect::<String>().to_uppercase(),
    }
}

async fn current() -> String {
    async {
        let conn = zbus::Connection::session().await?;
        ControllerProxy::new(&conn).await?.current_input_method().await
    }
    .await
    .unwrap_or_default()
}

async fn toggle() {
    if let Ok(conn) = zbus::Connection::session().await {
        if let Ok(p) = ControllerProxy::new(&conn).await {
            let _ = p.toggle().await;
        }
    }
}

struct App {
    core: cosmic::Core,
    im: String,
}

#[derive(Debug, Clone)]
enum Message {
    Current(String),
    Toggle,
    Settings,
}

impl cosmic::Application for App {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = "dev.dotfiles.CosmicAppletInput";

    fn core(&self) -> &cosmic::Core {
        &self.core
    }
    fn core_mut(&mut self) -> &mut cosmic::Core {
        &mut self.core
    }

    fn init(core: cosmic::Core, _: ()) -> (Self, Task<cosmic::Action<Message>>) {
        let task = Task::perform(current(), |im| cosmic::Action::App(Message::Current(im)));
        (App { core, im: String::new() }, task)
    }

    fn update(&mut self, message: Message) -> Task<cosmic::Action<Message>> {
        match message {
            Message::Current(im) => self.im = im,
            Message::Toggle => {
                return Task::perform(async { toggle().await; current().await }, |im| {
                    cosmic::Action::App(Message::Current(im))
                })
            }
            Message::Settings => {
                let _ = std::process::Command::new("fcitx5-configtool").spawn();
            }
        }
        Task::none()
    }

    fn subscription(&self) -> Subscription<Message> {
        Subscription::run_with_id(
            "fcitx5-input-method",
            stream::unfold((), |()| async {
                tokio::time::sleep(POLL).await;
                Some((Message::Current(current().await), ()))
            }),
        )
    }

    fn view(&self) -> Element<'_, Message> {
        let (major, minor) = self.core.applet.suggested_padding(true);
        let (h, v) = if self.core.applet.is_horizontal() { (major, minor) } else { (minor, major) };
        let button = widget::button::custom(
            widget::container(self.core.applet.text(label(&self.im)))
                .center_x(Length::Shrink)
                .center_y(Length::Fill),
        )
        .padding([v, h])
        .class(cosmic::theme::Button::AppletIcon)
        .on_press(Message::Toggle);
        MouseArea::new(button).on_right_press(Message::Settings).into()
    }

    fn style(&self) -> Option<cosmic::iced_runtime::Appearance> {
        Some(cosmic::applet::style())
    }
}

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<App>(())
}
