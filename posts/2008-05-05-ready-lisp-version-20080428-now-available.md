---
title: Ready Lisp version 20080428 now available
description: desc here
tags: SBCL, SLIME
date: 2008-05-05 04:21
category: Uncategorized
id: 166
---

There is a new version of Ready Lisp for Mac OS X available.  This version is based on SBCL 1.0.16, and requires OS X Leopard 10.5.  The most notable change from the previous version is that 64-bit mode and experimental threading are no longer supported, since both have been known to have issues on OS X, while the purpose of Ready Lisp is to smoothly introduce Common Lisp to new users.

<!--more-->
What is Ready Lisp?  It's a binding together of several popular Lisp packages for OS X, including: Aquamacs, SBCL and SLIME.  Once downloaded, you'll have a single application bundle which you can double-click -- and find yourself in a fully configured Common Lisp REPL.  It's ideal for OS X users who want to try out Lisp with a minimum of hassle.  [The download](ftp://ftp.newartisans.com/pub/lisp/ready-lisp/ReadyLisp.dmg) is approximately 76 megabytes.

There is a GnuPG signature for this file in the same directory; append `.asc` to the above filename to download it.  To install my public key onto your keyring, use this command:

    $ gpg --keyserver pgp.mit.edu --recv 0x824715A0

Once installed, you can verify the download using the following command:

    $ gpg --verify ReadyLisp.dmg.asc

For more information, see the [Ready Lisp project page](/software/readylisp.html).

