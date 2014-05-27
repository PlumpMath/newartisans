---
title: Using Archiveopteryx on the Mac
description: desc here
tags: Archiveopteryx, Gnus, IMAP, PostgreSQL, fetchmail, procmail
date: [2007-10-11 Thu 07:19]
category: Uncategorized
id: 194
---

The following instructions are for a Mac running OS X 10.4.  Your mileage may vary.  It's not much different for running on Linux, which I've done too.

<!--more-->
[Archiveopteryx](http://www.archiveopteryx.org/) is quite a wonderful little database store, which holds e-mail in a PostgreSQL database and lets you access it via the IMAP protocol.  It's aimed at long-term storage and high volume.

Why would you want to keep your mail in such a thing?  Well, it scales well, for one.  I have tens of thousands of e-mails right now -- since I don't like deleting them -- and it's just going to keep growing.  Also, using a real database to keep your mail is a solution that will stay practical up into the millions of messages, since it's not disk space we lack: but consistent and careful organization and indexing.  I think every e-mail system I've had has corrupted my data at least a few times, mainly because the data had gotten too large for me to "keep clean".  Archiveopteryx, however, uses database constraints and checks to ensure that whatever goes into the mail store is and remains compliant to a standard, RFC822-style structure.

## Setup PostgreSQL

To use Archiveopteryx, first you will have to install PostgreSQL.  Why PostgreSQL and not MySQL?  Well, Archiveopteryx only supports PostgreSQL, for one.  This is a Good Thing.  MySQL is handy when you need a place to keep data, but it's not really engineered from the ground up to keep your data sane.  Foreign key constraints were only added in 5.0 -- and then only if you use InnoDB tables, which have their own issues.  PostgreSQL has consistency checking, transactional support, and journaling.  It cares about your data more than almost anything else.

The easiest way to run PostgreSQL on your Mac is to install it using [MacPorts](http://www.macports.org/).  If you're not a MacPorts user yet, let this be your gentle introduction.  It's a very nice way to install free software projects on your Mac.

Once it's installed, just run these two commands at the Terminal:

	sudo port install postgresql82 postgresql82-server
	sudo /usr/local/lib/postgresql82/bin/initdb \
	     /usr/local/var/db/postgresql82/defaultdb
	sudo launchctl load -w \
	     /Library/LaunchDaemons/org.macports.postgresql82-server.plist

Linux users need to do something similar.  This is for CentOS/Redhat types:

	yum install postgresql postgresql-server
	service postgresql start
	chkconfig postgresql on

Now PostgreSQL is running, and will be running when you reboot too.

## Create an aox user and group, and add yourself to it

Again, for Mac users only, since we lack convenient `useradd` and `groupadd` commands.  You'll have to run Netinfo Manager, go into the "users" and "groups" directories, and copy the `postgres` user to a new `aox` user.  For the uid and gid, pick the next number after the `postgres` user.  Then, in the `aox` group, create a `users` property, and add two values: `aox` and your username.  Isn't Netinfo Manager lovely?

## Build and install Archiveopteryx

Now, from the Archiveopteryx sources, you can just run:

	sudo make install

After that's done, run this:

	export AOX=/usr/local/archiveopteryx
	sudo $AOX/lib/installer

This will create the necessary tables in the PostgreSQL database and get things ready.

## Start it running

Once the stage is set, it's time to put the players in action:

	sudo $AOX/bin/aox start

If you see no output from this command, that's a very good thing.  I get a warning about a failure from cryptlib to allocate memory, but it doesn't seem to cause a problem.  And it's only started happening since I rebooted.  Go figure.

## Create your first user

Create users and mailboxes in Archiveopteryx is trivial:

	sudo $AOX/bin/aox create user myuser pwd my@email.com

This creates a user named `myuser`, with password `pwd`, that will accept mail for `my@email.com`.  You can create aliases if you want a user to be able to accept mail for other addresses.  When you create the alias, you can even specify which mailbox the mail should be delivered to:

	sudo $AOX/bin/aox create alias workbox my@workemail.com

NOTE: Once you've logged out and back in again after your Netinfo Manager changes (see above, for Mac users only), you won't have to use `sudo` anymore.  Here's a quick way to suck in a big UNIX mailbox:

	formail -s $AOX/bin/deliver my@email.com , big.mbox

## Configuring fetchmail to deliver to Archiveopteryx

There are many ways to import old e-mail into Archiveopteryx.  The simplest way is to just copy it there using an IMAP client.  If you&#039;re a sysadmin type, there&#039;s the `aoximport` command, which understands UNIX mailboxes, Maildirs, etc.

For importing new mail, I use a combination of fetchmail and procmail.  If you want to use fetchmail only, use the `lmtp` and `smtphost` directives.  Archiveopteryx is capable of receiving mail over an LMTP socket, or using the `deliver` command that comes it.

## Configuring procmail to deliver to Archiveopteryx

I like to use procmail to deliver my mail, after suitable massaging and filtering, to eliminate duplicates and catch out special e-mails.  Here&#039;s the basic procmail file I use, in entirety:

	PATH=
	MAILDIR=$HOME/Mail
	LOGFILE=$MAILDIR/Library/Logs/procmail.log
	#VERBOSE=yes
	DELIVER=/usr/local/archiveopteryx/bin/deliver
	MYADDR=my@email.com

	######################################################################
	#
	# Backup the last 32 e-mails
	#
	######################################################################

	:0 c: backup.lock
	backup

	:0 ic
	| cd backup && /bin/rm -f dummy `ls -t msg.* | sed -e 1,32d`

	######################################################################
	#
	#  GNUS must have unique message headers, generate one if it isn't
	#  there. By Joe Hildebrand 
	#
	######################################################################

	:0 fhw
	| formail -a Message-Id: -a "Subject: (None)"

	######################################################################
	#
	# Remove messages with duplicate Message-ID's
	#
	######################################################################

	:0 Whc: msgid.lock
	| formail -D 32767 msgid.cache

	:0 a:
	dups

	######################################################################
	#
	# Remove the bogus >From header inserted by formail via fetchmail
	#
	######################################################################

	:0 fhw
	| perl -ne 'print unless /^>From johnw/;'

	######################################################################
	#
	# Immediately drop unwanted garbage we can't stop
	#
	######################################################################

	:0:
	* 
	/dev/null

	######################################################################
	#
	# Separate out mailing list messages
	#
	######################################################################

	:0
	* ^TO_
	| $DELIVER -t "Mailing Lists" $MYADDR

	######################################################################
	#
	# Catch out mail notices before checking for SPAM
	#
	######################################################################

	:0
	* ^Return-Path:.*apache@myserver.com
	| $DELIVER -t Notices $MYADDR

	######################################################################
	#
	# Remove SPAM
	#
	######################################################################

	:0
	* 
	| $DELIVER -t Junk $MYADDR

	######################################################################
	#
	# Notify via Growl if significant mail comes through
	#
	######################################################################

	SENDER=`formail -rtzxTo:`
	SUBJECT=`formail -zx Subject:`

	:0 cwir
	| growlnotify -a "Mail.app" -n "Mail.app" -t "$SENDER" -m "$SUBJECT"

	######################################################################
	#
	# Split for known targets
	#
	######################################################################

	:0
	* ^From:.*
	| $DELIVER -t Work my@workemail.com

	# All the rest goes into the INBOX

	:0
	| $DELIVER $MYADDR

## Connecting using Apple Mail

You may now connect to your new mail store using Apple Mail.  Create an IMAP account on `localhost` with the username and password you told Archiveopteryx.  For the SMTP server, also use `localhost`, but without a username or password.  Apple Mail is a handy client for creating and deleting mailboxes, and moving mail around.  Also, you can have it store a copy of the mail externally from the mail store for the purposes of Spotlight searching.  Yes, this more than doubles the among of space your mail takes up on the disk, but the searching and indexing advantages are worth it.  And you know that no matter how sketchy Apple Mail can get sometimes with tons and tons of e-mail, the mail kept in your store is there to last a lifetime.

## Connecting using Emacs Gnus

In a Gnus group buffer, use the `B` key and enter `nnimap` for the server.  Then pick `localhost`, and tell it the username and password you specified.  You can now move around to the groups you want to subscribe to, and type `u` to add them to your group buffer.  Now just type `g` and it will read the groups and present you with the latest and greatest.

I tend to use Apple Mail as my browser, and Gnus and my reading and writing tool.

