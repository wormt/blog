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

Frontmatter :: {}.{
	Metadata : {
		title : Str,
		date : Str,
		tags : List(Str),
		description : Str,
	}

	parse_frontmatter_block : Str -> Metadata
	parse_frontmatter_block = |block| {
		lines = Str.split_on(block, "\n")
		lines.fold({ title: "", date: "", tags: [], description: "" }, |acc, line| {
				trimmed = line.trim_start()
				match Str.split_first(trimmed, ": ") {
					Ok({ before: key, after: raw_value }) => {
						value = raw_value.trim_start()
						match key {
							"title" => { title: value, date: acc.date, tags: acc.tags, description: acc.description },
							"date" => { title: acc.title, date: value, tags: acc.tags, description: acc.description },
							"description" => { title: acc.title, date: acc.date, tags: acc.tags, description: value },
							"tags" => { title: acc.title, date: acc.date, tags: List.keep_if(Str.split_on(value, ",") |> List.map(|t| t.trim_start()), |t| !t.is_empty()), description: acc.description },
							_ => acc
						}
					}
					Err(_) => acc
				}
			})
	}

	parse_frontmatter! : Str => Metadata
	parse_frontmatter! = |source| {
		match Str.split_first(source, "---\n") {
			Ok(result) => {
				match Str.split_last(result.after, "---\n") {
					Ok(inner) => parse_frontmatter_block(inner.before)
					Err(_) => { title: "", date: "", tags: [], description: "" }
				}
			}
			Err(_) => { title: "", date: "", tags: [], description: "" }
		}
	}

	extract_body : Str -> Str
	extract_body = |source| {
		match Str.split_first(source, "---\n") {
			Ok(result) => {
				match Str.split_first(result.after, "---\n\n") {
					Ok(inner) => inner.after
					Err(_) => result.after
				}
			}
			Err(_) => source
		}
	}
}
