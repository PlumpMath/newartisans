---
title: Applescript and UTF-8 arguments
description: desc here
tags: 
date: 2007-10-01 20:16
category: Uncategorized
id: 195
---

The following tip is based on a hint by **mzs** found on MacOSXHints.com.  And **note:** this article relates only to Tiger.  This issue has been resolved in OS X Leopard and Applescript 2.0.

Although the Mac has been a great environment for working with UTF-8 text (8-bit Unicode), I've found a few corners where it's rather difficult to preserve the encoding of my text.  One of these is passing UTF-8 arguments to Applescripts on the command-line, using the `osascript` utility.

<!--more-->
To step back for a second: the reason I need UTF-8 support everywhere is that I sometimes work with Persian texts, which use an Arabic alphabet.  In general, most Cocoa application display Arabic text fairly well (though a large number of them have no clue when it comes to properly formatting right-to-left text; this means that when I type an exclamation mark, it often appears to the right of my entered text, rather than to the left).  But in the non-Cocoa world, which includes Carbon apps and the command-line, UTF-8 is either non-existent or very poor.

For example, as a result of my work in Persian, I have files that both contain Persian text and have Persian filenames.  The default setup for the Mac is pretty well suited for handling this at the Cocoa-level of things, such as the Finder, TextEdit, and so on.  But on the command-line, things are a bit different.  For one, Terminal.app must be reconfigured to properly display Unicode characters.  Then, you have to pass the `-w` flag to `/bin/ls` to get Unicode bytes in filenames to render correctly.

If you want pass a Persian filename to a script, many programs do not handle it at all.  Some work transparently -- they pass the encoded bytes right along to the underlying filesystem calls, which works great.  But others convert the encoded filenames to their own encoding (usually MacRoman) which completely destroys UTF-8 characters.  `osascript` is one of these.

If you write an Applescript with an "on run" handler, and call it with `osascript`, passing a UTF-8 encoded filename, your "on run" handler's argument list will look nothing like what you passed in.  But there is a trick for getting around this limitation.  It appears that `osascript` does not translate data passed in via pipe.  We can use this knowledge to trick `osascript` into reading its argument list in a different way instead of "on run".

To do this requires making a shell script with two forks.  The data fork is a regular shell script whose job is to package the argument list into a string that can be piped directly to `osascript`.  The resource fork is the Applescript itself, compiled to read and unpackage those arguments from the other side of the pipe.

First, the script template, which is always the same:

	#!/bin/sh

	case $# in
	0)
	    echo "Usage: ${0##*/} file [ file... ]" >&2
	    exit 1 ;;
	esac

	{   arg=$1
	    echo -nE "$arg"
	    shift

	    for arg in "$@"; do
	        echo -ne '\x00'; echo -nE "$arg"
	    done
	} | /usr/bin/osascript -- "$0"

Next, the Applescript template.  After this header, refer to your argument list using the `argv` list:

	set argv to do shell script "/bin/cat"

	set AppleScript's text item delimiters to ASCII character 0
	set argv to argv's text items
	set AppleScript's text item delimiters to {""}

	-- The rest of your script follows here...

To bind these pieces together, we'll assume you've called the shell script `template.sh`, and your Applescript `myscript.script`.  First you need to compile the Applescript:

	osacompile -o myscript.scpt -- myscript.script

Then bind the compiled Applescript to the resource fork of the final script:

	ditto -rsrc myscript.scpt myscript

Next, copy the shell script template to the data fork of the final script:

	cat -- template.sh > myscript

And finally, mark the script executable and delete the byproducts:

	chmod 755 myscript
	rm myscript.scpt

Now you can run `myscript` and pass it a UTF-8 encoded filename, and the Applescript will see it as a properly encoded string of type "Unicode text".

