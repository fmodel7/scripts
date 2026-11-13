"""Windows sound and Tk popup; called only by the UI thread."""
import math
import struct
import wave


def create_siren(path):
    if path.exists():
        return
    rate = 22050
    samples = bytearray()
    for i in range(rate * 3):
        frequency = 800 if int(i / rate / .4) % 2 == 0 else 1450
        samples.extend(struct.pack('<h', int(12000 * math.sin(2 * math.pi * frequency * i / rate))))
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(samples)


class Notifications:
    def __init__(self, root, settings, data_dir):
        self.root, self.settings = root, settings
        self.sound = data_dir / 'siren.wav'
        self.popup = None
        self.pending = set()

    def show(self, numbers):
        import tkinter as tk
        import winsound
        if self.settings.siren_enabled:
            create_siren(self.sound)
            winsound.PlaySound(str(self.sound), winsound.SND_FILENAME | winsound.SND_ASYNC)
        if not self.settings.popup_enabled:
            return
        self.pending.update(numbers)
        if self.popup is None:
            self.popup = tk.Toplevel(self.root)
            self.popup.title('Incident alert')
            self.popup.attributes('-topmost', True)
            self.label = tk.Label(self.popup, padx=30, pady=25, font=('Segoe UI', 16))
            self.label.pack()
            tk.Button(self.popup, text='Acknowledge', command=self.dismiss).pack(pady=15)
            self.popup.protocol('WM_DELETE_WINDOW', self.dismiss)
        self.label.config(text='Eligible incident(s) detected\n' + '\n'.join(sorted(self.pending)))
        self.popup.lift()

    def dismiss(self):
        import winsound
        winsound.PlaySound(None, 0)
        if self.popup is not None:
            self.popup.destroy()
            self.popup = None
        self.pending.clear()


def tray_image():
    from PIL import Image, ImageDraw
    image = Image.new('RGB', (64, 64), '#172033')
    draw = ImageDraw.Draw(image)
    draw.ellipse((8, 8, 56, 56), fill='#df394b')
    draw.rectangle((29, 18, 35, 39), fill='white')
    draw.ellipse((29, 44, 35, 50), fill='white')
    return image
