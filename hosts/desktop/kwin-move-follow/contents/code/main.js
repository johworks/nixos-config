for (let i = 1; i <= 10; i++) {
  registerShortcut(`Move and follow to desktop ${i}`, `Move window and follow to desktop ${i}`, "", () => {
    const window = workspace.activeWindow;
    const desktop = workspace.desktops[i - 1];
    if (!window || !desktop) return;

    window.desktops = [desktop];
    workspace.currentDesktop = desktop;
    workspace.activeWindow = window;
  });
}
