---
title: Test
date: 2025-07-10
tags: test, fuck
description: testing this thing
---

## Text Formatting

**bold**, *italic*, ***both***, ~~strike through~~

Inline code is wrapped in backticks: `console.log("hello world")`.

## Code Blocks

rust, nu

```rust
fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 0
        1 => 1
        _ => fibonacci(n - 1) + fibonacci(n - 2)
    }
}
```

```nu
def curlbash [...args] {
  let download = (^curl --proto '=https' --tlsv1.2 -sSfL ...$args)
  $download | less
  print ("Run script? (Y/n)")
  let user_input = (
    input -d 'y' | match $in {
      'Y' | 'y' | 'Yes' | 'yes' => true
      'N' | 'n' | 'No' | 'no' => false
    }
  )

  if ($user_input) {
    try {
      $download | bash
    }
  }
}
```

## Lists

### Unordered List

- one
- two
- three
- four

### Ordered List

1. one
2. two
3. three
4. four

## Blockquotes

> "foo bar foo bar foo bar foo
> bar foo bar foo bar foo bar"

## Line thing

---

## Links

- [GitHub](https://github.com/wormt)

## Images

![Lain Iwakura](https://upload.wikimedia.org/wikipedia/en/3/32/Serial_Experiments_Lain_DVD_vol_1.jpg?utm_source=en.wikipedia.org&utm_campaign=imageinfo&utm_content=thumbnail_unscaled)
