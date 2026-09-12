Fotos individuais usadas pela galeria de roupas
================================================

Coloque os PNGs dentro de `web/public/clothing`. O build copia essa pasta para a
NUI final automaticamente.

Estrutura:

- components/<key>/<numero_com_3_digitos>.png
- props/<key>/<numero_com_3_digitos>.png

Exemplos:

- components/torso/000.png
- components/torso/001.png
- components/pants/014.png
- props/hat/000.png
- props/glasses/027.png

Formato recomendado:

- PNG com fundo transparente
- 512 x 512 px
- personagem ou peça centralizada
- mesmo enquadramento e escala em toda a coleção
- nome correspondente ao drawable: 0 = 000.png, 18 = 018.png

Componentes disponíveis:

- head, mask, torso, undershirt, arms, vest, accessory, bag, pants, shoes, decals

Props disponíveis:

- hat, glasses, ears, watch, bracelet

Quando uma foto ainda não existe, a NUI usa o ícone ilustrado da categoria sem
quebrar a galeria. Os ícones ficam em `web/public/wardrobe-icons`.
