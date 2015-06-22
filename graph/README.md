This ipelet helps when drawing graphs.  To install the ipelet,
download [graph.lua](graph.lua) and copy it to `~/.ipe/ipelets/` (or
to some other directory for ipelets).

# Features #

The menu entry "toggle graph mode" turns a new graph editing mode on
and off (by default it is on).  The graph mode adds the feature that
vertices of a graph can be moved such that the incident edges follow
automatically.  At the moment this only works for vertices represented
by marks.

## Moving Vertices ##

Select a mark and press Ctrl+E to edit the position of the vertex.
Move the displayed cycle to a new position (changing its radius does
not have any effect) and press the space key.  The mark moves to the
new position and all endpoints of poly-lines and splines incident to
the previous position of the mark follow.

There are two different modes.  Either, only visible edges or all
edges on the current page are changed.  The menu entry "toggle move
invisible" switches between these two modes (by default only visible
edges are changed).

## Shortening Edges ##

Using the "shorten target/source/both" commands you can shorten edges
by a specified distance.  This is useful if you have directed edges
with arrowheads hiding under vertices (or vice versa).  Instead of
shortening each of them by hand, you can select all of them and run
the ipelet (at least if all vertices have the same size).

# Compatibility #

## Ipe Version ##

I tested the ipelet with versions 7.0.14 and 7.1.2 of Ipe.

## Presentation Ipelet ##

The graph iplet does not work together with the original version of
the presentation ipelet.  I'm using a modified [presentation
ipelet](presentation.lua).

# Changes #

**8 November 2013**
    new mode that only changes edges that are currently visible; see
    "Moving Vertices" (previously, all edges on the current page were
    modified) 

**7 May 2012**
    the Presentation Ipelet should now also work with Ipe 7.1.2

**29 April 2012**
    shortening edges should now work with version 7.1.2 of Ipe

**26 April 2012**
    first version of the Graph Ipelet online
