"""Tk runs on the main thread; tray callbacks communicate through a queue."""
import queue
import threading
from .notifications import Notifications, tray_image
from .worker import run_worker


class Application:
    def __init__(self, settings, data_dir):
        import tkinter as tk
        from tkinter import ttk
        import pystray
        self.settings, self.data_dir = settings, data_dir
        self.root = tk.Tk()
        self.root.title('SNOW Edge Monitor')
        self.root.geometry('620x370')
        self.events = queue.Queue()
        self.stop = threading.Event()
        self.thread = None
        self.closing = False
        self.notifications = Notifications(self.root, settings, data_dir)
        self.status = tk.StringVar(value='Stopped')
        self.count = tk.StringVar(value='Visible incidents: —')
        ttk.Label(self.root, text='SNOW Edge Monitor', font=('Segoe UI', 20, 'bold')).pack(pady=15)
        ttk.Label(self.root, textvariable=self.status, wraplength=580).pack(pady=8)
        ttk.Label(self.root, textvariable=self.count).pack()
        bar = ttk.Frame(self.root)
        bar.pack(pady=15)
        for title, command in [('Start', self.start), ('Stop', self.stop.set),
                               ('Test alert', self.test), ('Exit', self.exit)]:
            ttk.Button(bar, text=title, command=command).pack(side='left', padx=5)
        self.log = tk.Text(self.root, height=6, state='disabled', wrap='word')
        self.log.pack(fill='both', expand=True, padx=15, pady=10)
        ttk.Label(self.root, text='Closing the window hides it. Use Exit to stop the app.').pack(pady=5)
        self.root.protocol('WM_DELETE_WINDOW', self.root.withdraw)
        def item(title, event):
            return pystray.MenuItem(title, lambda *_: self.events.put((event, None)))
        self.tray = pystray.Icon('snow-edge-monitor', tray_image(), 'SNOW Edge Monitor', menu=pystray.Menu(
            item('Show', 'show'), item('Start', 'start'), item('Stop', 'stop'),
            item('Test alert', 'test'), item('Exit', 'exit')))
        self.tray_thread = threading.Thread(target=self.tray.run, daemon=True)
        self.tray_thread.start()
        self.root.after(150, self.process)

    def start(self):
        if self.closing or (self.thread and self.thread.is_alive()):
            return
        self.stop = threading.Event()
        self.thread = threading.Thread(target=run_worker, args=(
            self.settings, self.events, self.stop, self.data_dir / 'edge-profile'), daemon=True)
        self.thread.start()

    def test(self):
        self.notify(('INC9999999',))

    def notify(self, numbers):
        try:
            self.notifications.show(numbers)
        except Exception:
            self.write('Notification failed; check the Windows sound device and desktop session.')

    def exit(self):
        self.closing = True
        self.stop.set()
        self.status.set('Stopping; waiting for Edge to close...')

    def write(self, text):
        self.log.config(state='normal')
        self.log.insert('end', text + '\n')
        # Bounded in-memory log; never log incident numbers or configuration values.
        if int(self.log.index('end-1c').split('.')[0]) > 100:
            self.log.delete('1.0', '2.0')
        self.log.see('end')
        self.log.config(state='disabled')

    def process(self):
        try:
            while True:
                kind, value = self.events.get_nowait()
                if kind == 'status': self.status.set(value)
                elif kind == 'count': self.count.set(f'Visible incidents: {value}')
                elif kind == 'alert': self.notify(value)
                elif kind in ('failure', 'error'): self.write(value)
                elif kind == 'stopped': self.status.set('Stopped')
                elif kind == 'show': self.root.deiconify(); self.root.lift()
                elif kind == 'start': self.start()
                elif kind == 'stop': self.stop.set()
                elif kind == 'test': self.test()
                elif kind == 'exit': self.exit()
        except queue.Empty:
            pass
        if self.closing and (self.thread is None or not self.thread.is_alive()):
            self.notifications.dismiss()
            self.tray.stop()
            self.root.destroy()
            return
        self.root.after(150, self.process)

    def run(self):
        self.root.mainloop()
