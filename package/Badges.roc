# Copyright (C) 2026  wormt <209373679+wormt@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import pf.Html
import pf.HtmlAttributes

Badges :: {}.{
	html_badge : { src : Str, alt : Str, href : Str } -> Str
	html_badge = |badge|
	    Html.render_fragment(
	        Html.a(
	            [HtmlAttributes.href(badge.href)],
	            [
	                Html.img([
	                    HtmlAttributes.src(badge.src),
	                    HtmlAttributes.alt(badge.alt),
	                    HtmlAttributes.loading("lazy"),
	                ]),
	            ],
	        ),
	    ).concat("\n")

	badges : List({ src : Str, alt : Str, href : Str })
	badges = [
		{ src: "/badges/brainworm.webp", alt: "brainworm.homes", href: "https://brainworm.homes/" },
		{ src: "/badges/freerobuxextremist.webp", alt: "freerobuxextremist.com", href: "https://freerobuxextremist.com/" },
		{ src: "/badges/wormpinkbadge.webp", alt: "wormpinkbadge", href: "https://worm.pink/" },
		{ src: "/badges/stamp_pleroma_now.png", alt: "pleroma now", href: "https://pleroma.social/" },
		{ src: "/badges/servfail-88_31.png", alt: "servfail authoritative dns", href: "https://servfail.network/" },
		{ src: "/badges/fedora.gif", alt: "fedora", href: "https://fedoraproject.org/" },
		{ src: "/badges/poweredbynixos.png", alt: "poweredbynixos", href: "https://github.com/nix-caliga/nix-caliga" },
		{ src: "/badges/grapheneos.gif", alt: "grapheneos", href: "https://grapheneos.org/" },
		{ src: "/badges/ed.webp", alt: "ed", href: "https://www.gnu.org/software/ed/" },
		{ src: "/badges/vim_a.gif", alt: "vim", href: "https://www.vim.org/" },
		{ src: "/badges/nocookie.gif", alt: "nocookie", href: "https://brainworm.homes/" },
		{ src: "/badges/nojs.gif", alt: "nojs", href: "https://brainworm.homes/" },
		{ src: "/badges/deadlyprogramming.gif", alt: "deadlyprogramming", href: "https://brainworm.homes/" },
		{ src: "/badges/seedyourtorrents.gif", alt: "seedyourtorrents", href: "https://brainworm.homes/" },
		{ src: "/badges/eff.png", alt: "eff", href: "https://www.eff.org/" },
		{ src: "/badges/tor.gif", alt: "tor", href: "https://www.torproject.org/" },
		{ src: "/badges/fuckdrm.gif", alt: "fuckdrm", href: "https://www.defectivebydesign.org/" },
		{ src: "/badges/ipv6.gif", alt: "ipv6", href: "https://brainworm.homes/" },
		{ src: "/badges/lynx_enh.gif", alt: "lynx enh", href: "https://lynx.invisible-island.net/" },
		{ src: "/badges/monero-now.gif", alt: "monero now", href: "https://www.getmonero.org/" },
		{ src: "/badges/mousepow.gif", alt: "mousepow", href: "https://web.archive.org/web/20241203100136/https://ratmaxx.ing/" },
		{ src: "/badges/osamasux.gif", alt: "osamasux", href: "https://navy.com/" },
		{ src: "/badges/raspberryheaven.png", alt: "raspberryheaven", href: "https://en.wikipedia.org/wiki/Azumanga_Daioh" },
		{ src: "/badges/sucks.gif", alt: "sucks", href: "https://brainworm.homes/" },
		{ src: "/badges/ffmpeg.gif", alt: "ffmpeg", href: "https://ffmpeg.org/" },
		{ src: "/badges/ie_exploder.gif", alt: "ie exploder", href: "https://en.wikipedia.org/wiki/IEs4Linux" },
		{ src: "/badges/bunbrowser.gif", alt: "bunbrowser", href: "https://github.com/netsurf-plan9/nsport" },
		{ src: "/badges/joebidenapproved.webp", alt: "joebidenapproved", href: "https://fuckgov.org/@joebiden" },
		{ src: "/badges/assadapproved.webp", alt: "assadapproved", href: "https://files.catbox.moe/87xzfk.mp4" },
		{ src: "/badges/miku.gif", alt: "miku", href: "https://files.catbox.moe/ckg2mr.mp4" },
		{ src: "/badges/konko.gif", alt: "konko", href: "https://files.catbox.moe/iweerz.mp4" },
		{ src: "/badges/hello_kitty.gif", alt: "hello kitty", href: "https://files.catbox.moe/rj3y7h.gif" },
		{ src: "/badges/capybara.png", alt: "capybara", href: "https://github.com/looskie/capybara-api" },
		{ src: "/badges/containsasbestos.webp", alt: "containsasbestos", href: "https://brainworm.homes/" },
		{ src: "/badges/banporn.gif", alt: "banporn", href: "https://brainworm.homes/" },
		{ src: "/badges/cc-by-sa.gif", alt: "cc by sa", href: "https://creativecommons.org/licenses/by-sa/4.0/" },
		{ src: "/badges/agpl3pin.gif", alt: "agpl3pin", href: "https://www.gnu.org/licenses/agpl-3.0.html" },
	]
}
