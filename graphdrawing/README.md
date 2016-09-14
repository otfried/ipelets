# Graph drawing ipelet

This ipelet gives Ipe access to the graph drawing functions provided
by Tikz.  See below for installation instructions.

### Usage

Draw a graph, for instance the following:

![graph1.ipe](screenshots/graph1.tiff "graph1.ipe")

Select all its nodes and vertices, and call the desired layout method
of the ipelet. (You'll need to read the Tikz manual to understand the
precise options.)  Here is the result if you choose `spring electrical
layout`:

![automatically layed out graph1.ipe](screenshots/graph1a.tiff "graph1.ipe with spring elecrical layout")

### What is a graph?

The ipelet uses a simple heuristic to determine edges and vertices of
the graph:

- A path object with a single open curve is considered an edge.

- A group object (e.g. a box with a text label inside, grouped
  together), a text object, or a refence to a symbol is considered
  a vertex.

- The ipelet uses the bounding box of each vertex to determine which
  vertices are connected by an edge.  If your vertices are very close
  together (or even overlap), this will not work correctly.


### Installation

Copy the file `graphdrawing.lua` into one of your ipelet directories
(see Help -> Show configuration in Ipe).

You will need to edit the file to indicate the location of the Tikz
graph drawing library in the variable `pgf_gd_path` (about line 11 in
`graphdrawing.lua`).

To find the correct location, run `kpsewhich gd.lua` from the command
line, like this:

```
$ kpsewhich gd.lua
/usr/local/texlive/2015/texmf-dist/tex/generic/pgf/graphdrawing/lua/pgf/gd.lua
```

The correct variable setting is obtained by deleting `/pgf/gd.lua` from
the end of this string, in this case it would be

```
local pgf_gd_path = "/usr/local/texlive/2015/texmf-dist/tex/generic/pgf/graphdrawing/lua"
```

If your Latex installation does not contain Tikz, or only a version of
Tikz earlier than Tikz 3.0, then `kpsewhich gd.lua` will not find
anything.  In this case you will need to download the Tikz library
yourself, from https://sourceforge.net/projects/pgf/files/latest/download.

Unzip the package anywhere you like, e.g. into `$HOME/Devel/tikz`.
The correct variable setting for `graphdrawing.lua` is then:

```
local pgf_gd_path = "/home/otfried/Devel/tikz/tex/generic/pgf/graphdrawing/lua"
```







