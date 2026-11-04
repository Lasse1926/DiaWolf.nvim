# DiaWolf.nvim
Neovim toolkit for authoring ER diagrams with Chen notation, PlantUML generation, and convenient editing commands.

## Config

### Lazy

```lua
{
    "Lasse1926/diawolf.nvim",
    ft = "plantuml", -- load only when a PlantUML file is opened
    opts = {
        plantuml_jar = "path/to/plantuml.jar",
    },
}
```

`ft = "plantuml"` lazy-loads the plugin when you open a PlantUML file.
### Filetype detection
DiaWolf ships `ftdetect/plantuml.lua`, which sets the `plantuml` filetype for these extensions:
`.puml`, `.plantuml`, `.pu`, `.iuml`, `.wsd`

