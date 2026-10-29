/// `oriel --help` (PLAN §7.1.8).
enum Usage {
    static let text = """
    usage: oriel <command> [options]

    Window switcher
      oriel windows list [--json] [--space current|all] [--app <bundle-id>]
      oriel windows focus <window-id> | --title <substring>
      oriel windows close <window-id>
      oriel windows minimize <window-id>

    Capture and translate
      oriel capture area|window|screen [--rect x,y,w,h] [--delay <seconds>] [--to clipboard|file|editor] [--path <file>]
      oriel translate area [--rect x,y,w,h] [--to <language>] [--provider <id>] [--json]

    Diagnostics
      oriel debug capabilities --json
      oriel debug clipboard [--json]               Clipboard History's state, never its contents
      oriel debug open-switcher --shortcut <n>     (Debug builds)
      oriel debug capture --fixture <png>          (Debug builds)
      oriel debug record --seconds <n> [--pause-at <s> --resume-at <s>]   (Debug builds)
      oriel debug perf-capture [--runs <n>] [--json]                     (Debug builds)

    Other
      oriel --help | --version
      --timeout <seconds> overrides how long to wait for Oriel to answer.

    Oriel must be running; the CLI talks to it over a private socket in ~/Library/Application Support/Oriel.
    """
}
