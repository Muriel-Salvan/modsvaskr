# Modsvaskr - Stronghold for mods acting like companions: The Modsvaskr

Command-line UI handling a full Mods' ecosystem for Bethesda's games.

## Description

Heavy mods' user often have **hard times when they want to get a stable modded game**.
A lot of tools are already helping a lot:
* [Mod Organizer](https://www.nexusmods.com/skyrimspecialedition/mods/6194)
* [LOOT](https://loot.github.io/)
* [xEdit](http://tes5edit.github.io/)
* Plenty of tools to create patches, merge, generate content like LODs etc...

Most of the time, gamers have to perform the following tasks every time their mods list changes:
* **Read carefully** all the descriptions of each mod they use.
* **Re-install mods having patches** for newly added mods (using FOMOD installers for the easiest, and search/install patches from NexusMods for others).
* **Correct all errors and warnings** reported by tools like LOOT (change mods list upon incompatibilities, clean esps from dirty records...).
* **ESLify some esps** if they need to get below the 254 esps limit of the new mods.
* **Merge esps** if eslification is not enough to keep below the limit.
* **Manually patch some mods** using tools like xEdit or the Creation Kit, or sometimes files renaming.
* **Re-generate all generated content**, like LODs, FNIS animations, Patches...
* And **test, test, test** - usually breaking the immersive experience of discovering added content naturally in game: to test new mods they usually have to visit changed locations, fly around in high-speed, summon NPCs to check for black faces, etc...

Given those tedious tasks, gamers have basically few choices:
* Rely only on mods lists already tested and curated by other modders (like the excellent [S.T.E.P. guide](https://wiki.step-project.com/Main_Page)), or
* Keep the mods number relatively small, and remove mods before adding new ones (therefore having to start games from scratch), or
* Learn skills of an experienced modder to be able to solve the previous points easily (takes a loooot of time, comprehension and curiosity), or
* Accept to have a game that is not stable, ruining the gaming experience, or
* Ask Modsvaskr for help ;-)

Modsvaskr is here to help gamers do the following:
* **Automate repeatible and tedious tasks** they have to do while updating their mods list (patchs, LODs...).
* **Automate lot of testing** so that they can detect quickly without manually tests, and without having to discover mods before-hand and ruin their in-game experience (automatically load changed locations, new NPCs...).
* **Detect issues early**, so that they can focus of solving the most important issues in their mods list.
* Simplify the way non-modder gamers can **improve and automate their gaming experience**.

The goal as a gamer using Modsvaskr is to be able to:
* **Easily update a mods list** without fear or forgetting some processing, for a large number of mods (over 1000).
* Know quickly and without human intervention **what could go wrong** in using all those mods.
* Solve problems that could be **solved automatically**.
* **Not spoil the mods' content** while testing for in-game stability.

## Games

The list of games that should be compatible with Modsvaskr are the following:
* Skyrim.
* Skyrim Special Edition - Tested successfully.
* Fallout 4.

The list of supported games in the current version of Modsvaskr is found in the [`lib/modsvaskr/games`](lib/modsvaskr/games) folder.
Adding a new compatible game should be as easy as adding a file in this directory and implementing its API in Ruby.

## Install

Via gem

``` bash
$ gem install modsvaskr
```

Using `bundler`, add this in your `Gemfile`:

``` ruby
gem 'modsvaskr'
```

## Usage

Modsvaskr needs a configuration file to be created in the current directory from which it is executed, named `modsvaskr.yaml`.
Check the [`modsvaskr.yaml.sample`](modsvaskr.yaml.sample) file to know how to create it.

running Modsvaskr is done this way:

``` bash
modsvaskr
```

## Change log

Please see [CHANGELOG](CHANGELOG.md) for more information on what has changed recently.

## Contributing

Any contribution is welcome:
* Fork the github project and create pull requests.
* Report bugs by creating tickets.
* Suggest improvements and new features by creating tickets.

## Credits

- [Muriel Salvan][link-author]

## License

The BSD License. Please see [License File](LICENSE.md) for more information.
