# Deixa a moldura Samsung só com o aparelho: tira o cartão azul e o nome do modelo.
# Uso: python -I so-aparelho.py <pasta-da-skin>   (usa _original\ como fonte; cria se não existir)
import site, sys, os, shutil
sys.path.append(site.getusersitepackages())
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

pasta = sys.argv[1]
orig = os.path.join(pasta, "_original")
if not os.path.isdir(orig):
    os.makedirs(orig)
    for f in ("device_Port_Black.png", "layout"):
        shutil.copy2(os.path.join(pasta, f), orig)

im = Image.open(os.path.join(orig, "device_Port_Black.png")).convert("RGBA")
X0, Y0, X1, Y1 = 300, 292, 1490, 2742  # caixa do aparelho (com botões laterais)
im = im.crop((X0, Y0, X1, Y1))
a = np.asarray(im).astype(np.int16)
r, g, b, alfa = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
# Fundo do cartão é azulado (b bem maior que r); o aparelho é preto/cinza neutro.
corpo = (b - r < 12) & (alfa > 0)
rot, n = ndimage.label(corpo)
maior = 1 + int(np.argmax(ndimage.sum(np.ones_like(rot), rot, range(1, n + 1))))
mascara = ndimage.binary_fill_holes(rot == maior)
mascara = ndimage.binary_opening(mascara, iterations=2)
m = Image.fromarray((mascara * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
im.putalpha(m)
im.save(os.path.join(pasta, "device_Port_Black.png"))

lay = open(os.path.join(orig, "layout"), encoding="utf-8").read()
dx, dy = X0, Y0
troca = {
    "x		1473": f"x		{1473 - dx}",
    "y		722": f"y		{722 - dy}",
    "y		884": f"y		{884 - dy}",
    "y		1199": f"y		{1199 - dy}",
    "width     1785": f"width     {X1 - X0}",
    "height    3030": f"height    {Y1 - Y0}",
    "x       352": f"x       {352 - dx}",
    "y       341": f"y       {341 - dy}",
}
for k, v in troca.items():
    assert k in lay, k
    lay = lay.replace(k, v)
open(os.path.join(pasta, "layout"), "w", encoding="utf-8", newline="\n").write(lay)
print("ok", im.size, "pixels do aparelho:", int(mascara.sum()))
