#!/usr/bin/perl

use inc::Module::Install;

name         ('PerlIO-eol');
author       ('Audrey Tang <audreyt@audreyt.org>');
abstract     ('PerlIO layer for normalizing line endings');
license      ('perl');
version_from ('eol.pm');
requires     (perl => '5.7.3');

WriteAll     (sign => 1);
