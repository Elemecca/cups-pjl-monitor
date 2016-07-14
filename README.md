# CUPS PJL Status Monitor

[![Build Status](https://travis-ci.org/Elemecca/cups-pjl-monitor.svg?branch=master)](https://travis-ci.org/Elemecca/cups-pjl-monitor)

This project provides a plugin for [CUPS][cups-home] that enables job
status monitoring for printers that support [HP PJL][pjl] including job
and page completion notifications.

[cups-home]: https://github.com/apple/cups#readme
[pjl]: http://h20000.www2.hp.com/bc/docs/support/SupportManual/bpl13208/bpl13208.pdf



## FAQ

### What's the status of this project?

The `pjl` filter is still in early development. It's not usable yet
unless you're feeling *really* adventurous. Check back soon.

### Will the PJL monitor ever become part of CUPS itself?

Not according to [Michael Sweet on `cups-devel`][cups-devel]:

> PJL and other mechanisms do not scale and suffer from versioning and
> communication issues. And quite frankly AppSocket (and LPD) are dead
> as far as future development goes. All modern (since 2010) network
> printers support IPP and IPP's rich job monitoring, even for (legacy)
> PostScript jobs.
>
> > Is this something that should be contributed to CUPS proper?
>
> Maybe the cups-filters project, but I can tell you we won't accept
> this into CUPS itself due to the support burden and the lack of need
> for current, vendor-supported printers.

Since it's still useful for certain older printers and print servers
this filter will be maintained as its own project as long as there's
a sufficient community to keep it going.

[cups-devel]: http://www.cups.org/pipermail/cups-devel/2016-July/016837.html



## Copyright

Copyright &copy; 2016 Sam Hanes

Like CUPS itself, this project is provided under the terms of version 2
of the GNU General Public License (GPLv2).

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software foundation, Inc.,
675 Mass Ave, Cambridge, MA 02139, USA.
