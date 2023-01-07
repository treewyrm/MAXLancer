# Materials

Take following steps to change material into Freelancer material:

1. Open *Compact Material Editor*.
2. Select material slot to modify.
3. Click on type button next to material name field (usually it is *Standard* or *Physical Material*).
4. In Material/Map Browser select **Materials → General → DirectX Shader**.
5. Select *Discard old material* and press *OK* in Replace Material dialog window.
6. In *DirectX Shader parameters* group click on filename button to the left of Reload button.
7. Navigate to MAXLancer folder and select .fx file based on what material type you want to use (typically it will be SinglePassMaterial.fx).

An extra caution should be exercised when it comes to material names. As with objects in scene 3ds Max permits multiple materials to have same names and this can cause problems later.

Freelancer stores and retrieves materials by name, once a material has been loaded it will not be overwritten until material library is flushed, which typically occurs when switching between systems and scenes. As such you must avoid different materials having duplicate names.

This doesn't mean that for every material you use must provide unique name. If you use existing materials and don't alter them then continue to use their original names and reference original .mat files in object archetypes (such as ones defined in solararch.ini, shiparch.ini, etc).

When exporting rigid model you have an option whether to embed materials and textures into resulting model file. For objects such as ships and stations materials are often stored in a separate .mat file and linked to as material_library property within archetype in INI file. A few exception exists where regardless of use case for materials and textures you must embed these resources into model file: starspheres and cutscene objects referenced in petaldb.ini.

Following material types are supported in MAXLancer:

| Shader file           | Material type          | Alpha | Description                                                                                                                                     |
| --------------------- | ---------------------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| SinglePassMaterial.fx | DcDt                   | No    | Simple opaque material with diffuse texture and diffuse color tint.                                                                             |
|                       | DcDtTwo                | No    |                                                                                                                                                 |
|                       | DcDtOcOt               | Yes   | Transparent material with diffuse texture, diffuse color and opacity from diffuse texture alpha channel w/explicit value.                       |
|                       | DcDtOcOtTwo            | Yes   |                                                                                                                                                 |
|                       | DtDtEc                 | No    | Opaque material with diffuse texture, diffuse color and emission color.                                                                         |
|                       | DcDtEcTwo              | No    |                                                                                                                                                 |
|                       | DcDtEcOcOt             | Yes   | Transparent material with diffuse texture, diffuse color, emission color and diffuse texture alpha channel w/explicit value.                    |
|                       | DcDtEcOcOtTwo          | Yes   |                                                                                                                                                 |
| DetailMaterial.fx     | BtDetailMapMaterial    | No    | Diffuse texture with overlay detail material on second texture map channel.                                                                     |
|                       | BtDetailMapMaterialTwo | No    |                                                                                                                                                 |
| Nebula.fx             | Nebula                 | Yes   | Additive blending material. Used for starscapes.                                                                                                |
|                       | NebulaTwo              | Yes   |                                                                                                                                                 |
| GlassMaterial.fx      | GlassMaterial          | Yes   | Transparent material with specular effect. Used for fighter cockpits.                                                                           |
|                       | GFGlassMaterial        | Yes   |                                                                                                                                                 |
|                       | HighGlassMaterial      | Yes   |                                                                                                                                                 |
| NomadMaterial.fx      | NomadMaterial          | Yes   | Transparent material with wrapped environment map. Used by nomad ships. Cannot be combined with regular environment map specified in archetype. |
|                       | NomadMaterialNoBendy   | Yes   |                                                                                                                                                 |

# Textures

Textures are expected in uncompressed Targa (.tga) format with 24 or 32 bit depth, or DirectDrawSurface (.dds) with DXT1, DXT3, DXT5 compression or uncompressed. Internal DDS mipmaps are supported. For Targa mipmaps are individual files, RLE compression is unsupported.

Depending on filename pattern textures can be compressed automatically upon exporting materials:

| Pattern      | Description                                                              |
| ------------ | ------------------------------------------------------------------------ |
| \*_dxt1.tga  | Export as MIPS inverted DDS compressed DXT1.                             |
| \*_dxt1a.tga | Export as MIPS inverted DDS compressed DXT1a.                            |
| \*_dxt3.tga  | Export as MIPS inverted DDS compressed DXT3.                             |
| \*_dxt5.tga  | Export as MIPS inverted DDS compressed DXT5.                             |
| \*_rgba.tga  | Export as MIPS inverted DDS uncompressed 32-bit RGBA.                    |
| \*_mip0.tga  | Export as sequence of MIP0 to maximum level found in matching filenames. |
| \*.tga       | Unmatched .tga exported as MIP0 only.                                    |
| \*.dds       | Unmatched .dds exported as MIPS without vertical flip.                   |