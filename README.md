# TWUI Reloader (Modding tool)
This modification assists modders in avoiding layout file caching, allowing them to focus on creating mods without fighting with the game engine.

## Usage
Simply call `UIComponent.CreateComponent` or `core:get_or_create_component` and forget about manually changing filenames :)

Additionally, mod provides function `LayoutReloader.create_or_recreate_component` that behaves similarly to `core:get_or_create_component`. The key difference is that if the component already exists, it will be removed and then recreated.

## Installation
Enable the `.pack` mod file to load with the game. 

On first load, the mod will create temporary files to work with. A game restart is required after that. On the next game execution, you can start working on your layout modifications.

## How it works
Every time you use the `UIRoot.CreateComponent` or `core:get_or_create_component` functions, the script checks if the corresponding file exists in the `data/ui` folder. If the file exists and has been modified, the script will copy its content to the previously created temporary file, preventing caching. This operation performs recursively for sublayouts within that file.

It seems that the game engine caches the paths of existing files during loading. Therefore, the script creates a pool of temporary files under data/ui/temp to handle copies of your layouts. All temporary files must exist before the game starts.

We also need request file modification time. Sadly but Lua has limited native support to work with file system, so the only option we have in Lua is to use `os.execute` or `io.popen` functions to make requests to the operating system using `cmd`. However, each time a request is made, a new `cmd.exe` window is created. I found that subsequent requests result in significant freezing (idk why). They last around 8-10 seconds on my laptop. To avoid such freezes, I decided to spawn a separate process to handle the file information requests. Another process is created to transmit results from the main process (because we dont have duplex IPC support in Lua). Both processes are spawned whenever the game enters campaign or battle modes and are terminated when the game exits those modes. 

Although it would be possible to create a separate `.exe` to monitor the file system, I wanted to avoid imposing additional steps on the user to utilize this tool.