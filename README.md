![shesells_promo_1920x1080 thumb png 48d4812ad915378184fec73d9c2daf00](https://github.com/user-attachments/assets/89c480c3-3e4b-477e-9bf1-3425d4e2b236)


# PearlOS
An extensive set of software tools for managing and operating your starving servers!

## Installation
The installation process is very simple since the mod is available on Steam Workshop.
All you have to do in order to download the files is to add the following line to your `dedicated_server_mods_setup.lua` in your `...\steamcmd\steamapps\common\Don't Starve Together Dedicated Server\mods` folder:
```lua
  ServerModSetup("3122299418")
```
This will make sure, that the newest version of Pearl's script files is downloaded and installed by the game each time you boot up your DST server.
Now to enable this mod you will want to add the following to your `modoverrides.lua` file in each of the shard folders you want it to be enabled:
```lua
  ["workshop-3122299418"] = {
    enabled = true,
  },
```
Notice how the number after the "workshop-" part is the same as the number passed as a string to the `ServerModSetup` function in the line above.
This is the ID of the modification taken from Steam Workshop. The "workshop-" part is just a simple prefix the game uses to easily recognize mods that can be download from Steam Workshop.

## Configurations

| Option Name   | Description   | Type | Default  |
| ------------- | ------------- | ---- | -------- |
| SOCIAL_LINKS.DISCORD  | Link to the Discord server you want to advertise using social link buttons displayed in the lobby and player listing screen.  | string | nil |
| SOCIAL_LINKS.TWITCH   | URL of the Twitch account you want to advertise using social link buttons displayed in the lobby and player listing screen.  | string | nil |
| SOCIAL_LINKS.YOUTUBE   | URL of the YouTube channel you want to advertise using social link buttons displayed in the lobby and player listing screen.  | string | nil |

~~# Documentation~~
~~https://doc.clickup.com/9004078370/p/h/8cayn92-661/edf132b39ec0aae/8cayn92-661~~
