//! Embeds the built interface in the executable: see brigid-ui-embed (core).
//! `BRIGID_UI_DIST` names the `dist` directory of a build of `brig-id/app`;
//! a release build requires it.

fn main() {
    brigid_ui_embed::embed_interface();
}
