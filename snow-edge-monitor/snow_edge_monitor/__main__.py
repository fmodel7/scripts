"""CLI entry point; importing this module does not launch the app."""
import argparse
from pathlib import Path
import sys
from .config import load_settings, runtime_dir


def main(argv=None):
    parser = argparse.ArgumentParser(description='SNOW Edge Monitor for Windows')
    default_config = Path(sys.executable).parent / 'config.json' if getattr(sys, 'frozen', False) else Path('config.json')
    parser.add_argument('--config', type=Path, default=default_config)
    args = parser.parse_args(argv)
    if sys.platform != 'win32':
        parser.exit(2, 'The desktop application requires Windows 10/11 and Microsoft Edge.\n')
    try:
        settings = load_settings(args.config)
    except ValueError:
        message = 'Cannot load configuration. Copy config.example.json to config.json and review the README.'
        if getattr(sys, 'frozen', False):
            from tkinter import messagebox
            messagebox.showerror('SNOW Edge Monitor', message)
            return 2
        parser.exit(2, message + '\n')
    from .ui import Application
    Application(settings, runtime_dir()).run()


if __name__ == '__main__':
    raise SystemExit(main())
