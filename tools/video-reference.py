"""Extract a timestamped contact sheet from a local reference video."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.video-deps'))
import av
from PIL import Image, ImageDraw

source = Path(sys.argv[1])
output = Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
container = av.open(str(source))
stream = container.streams.video[0]
duration = float(stream.duration * stream.time_base)
print(f'{stream.width}x{stream.height}, {duration:.2f} seconds', flush=True)
times = [duration * i / 19 for i in range(19)]
tiles = []
for index, seconds in enumerate(times):
    container.seek(int(seconds / stream.time_base), stream=stream)
    for frame in container.decode(stream):
        if float(frame.time) + 0.04 >= seconds:
            picture = frame.to_image()
            picture.save(output / f'frame-{index:02d}.jpg')
            picture.thumbnail((380, 260))
            tile = Image.new('RGB', (400, 290), '#15232b')
            tile.paste(picture, ((400-picture.width)//2, 24))
            ImageDraw.Draw(tile).text((10, 6), f'{seconds:.1f}s / frame {index}', fill='white')
            tiles.append(tile)
            break
sheet = Image.new('RGB', (1600, ((len(tiles)+3)//4)*290), '#15232b')
for i, tile in enumerate(tiles): sheet.paste(tile, ((i%4)*400, (i//4)*290))
sheet.save(output / 'contact-sheet.jpg')
