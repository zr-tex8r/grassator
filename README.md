THE GRASSATOR PACKAGE
=====================

The grassator package provides you a small environment where you can
write and/or execute programs in Grass and its derivatives.

[Grass][] is a "functional grass-planting programming language"
created by UENO Katsuhiro. The major feature of this language is
that all the source code consist only of three letters: W, w
and v (other characters are ignored).
The grassator package additionally supports one of Grass' derivative
languages, [Homuhomu][] created by "yuroyoro".

[Grass]: <http://www.blue.sky.or.jp/grass/>
[Homuhomu]: <http://d.hatena.ne.jp/yuroyoro/20110601/1306908421>

Installation
------------

This package requires that you have a working environment
of Lua 5.1 or 5.2.
It consists of three files:

  * grassator.lua: The main (executable) script.
  * planter.lua: The planter module, for conversion between
    various forms of Grass abstract programs.
  * bushfire.lua: The bushfire module, an interpreter of Grass.

After that you place the two module files (planter.lua and
bushfire.lua) in your Lua library path, you can invoke
grassator.lua by the Lua interpreter in the standard way,
ie. if the name of Lua interpreter executable is "lua" then
do as follows:

    # lua grassator.lua <arguments>

Alternatively, you can put the module files in the same
directory where grassator.lua resides.
You can use the shebang mechanism to make the script file
executable on the system that supports the mechanism.

In the rest of the document, I assume the main program
(grassator.lua) can be invoked by the command name `grasstor`.

Usage
-----

The invocatoin `grasstor -h` shows you the brief descrition
of usage as follows:

    This is grassator, v1.0.0<2016/11/23> by ZR(T.Yato)
    Usage:
    (as interpreter)
      grassator [-f LANG] [-d] [-s] [-S] [INFILE]
    (as converter)
      grassator [-f LANG] -t LANG [-d] [-S] [INFILE [OUTFILE]]
    Options:
      -f lang    Input language name. The default value is 'grass' (in
                 interpreter mode) or 'seed' (in converter mode).
      -t lang    Output language name.
      -d         Enable debug mode.
      -s         Enable stat mode.
      -S         Assume program source is in SJIS instead of UTF-8
      infile     Input file name (default=stdin).
      outfile    Output file name (default=stdout).
    Supported languages:
      seed / grass / homuhomu / snowman / zundoko / expandafter
      ('seed' can be used only as input)

Here shows some examples of command line input.

  * To execute a program in the Grass language:

        grassator program.www

    (Note that `-f grass` is omitted as default.)

  * To execute a program in the "seed" language:

        grassator -f seed program.sd

  * To execute a program in Grass, with debug messages:

        grassator -d program.www

    (The debug messages go to stderr.)

  * To convert a program from "seed" to Grass:

        grassator -t grass program.sd program.www

  * To convert from "seed" to Grass, run as filter:

        grassator -t grass

  * To convert a program from Grass to Homuhomu:

        grassator -f grass -t homuhomu program.www program.homu

License
-------

This software is distributed under the MIT License.

---

Takayuki YATO (aka "ZR")
