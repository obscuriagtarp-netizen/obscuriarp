# Imagens da Automotiva Akuma

Place your custom mechanic menu images here.

Recommended structure:

```txt
images/
  categories/
    performance.png
    bodywork.png
    wheels.png
    colors.png
    lights.png
    extras.png
  options/
    engine.png
    brakes.png
    transmission.png
    suspension.png
    turbo.png
```

Os caminhos são configurados em `shared/config.lua`, dentro de `MechanicConfig.UI`.
PNG, JPG e WEBP são aceitos pelo manifest. Quando `optionImages` não possui uma imagem específica, a interface reutiliza a arte da categoria.
