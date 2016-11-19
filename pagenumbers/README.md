**Note:** Most of the functionality of this ipelet is built into Ipe
7.2.4 and higher.  See the section *Presentation stylesheets* in the
manual.  Additional features provided by this ipelet are the
possibility to hide page numbers on some pages and to have pages that
do not increase the page counter.

This ipelet provides some page numbering features that are not covered
by the built in page numbering mechanism.  To install the ipelet,
download
[pagenumbers.lua](pagenumbers.lua)
and copy it to `~/.ipe/ipelets/` (or to some other directory for
ipelets).

# Usage #

To enable page numbering, add a layer with the name
*pagenumbers_format* to the first page.  The text objects in that
layer are copied to every page where every occurrence of the
placeholder `[page]` is replaced by the current page number.  This is
done every time latex runs.

## Special Layers ##

In addition to the layer *pagenumbers_format* there are other layers
with a special meaning.

***pagenumbers_format*** 

On this layer the format for the page numbers is specified (see
description above).  It is not necessary (and usually not desired)
that this layer is visible.

***pagenumbers_page***

This layer contains the page number and is automatically created on
every page.  To hide the page number on a specific page, just make
this layer invisible.

***pagenumbers_dont_count***

If a page contains this layer, the page count is not increased for
this page.


# Example #

See the file
[pagenumbers-example.ipe](pagenumbers-example.ipe)
for an example.

# Changes #

**08 November 2013**
first version of the pagenumbers ipelet online
