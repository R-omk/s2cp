package main

import (
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/klauspost/compress/s2"
)

var (
	compress   = flag.Bool("c", false, "Compress input")
	decompress = flag.Bool("d", false, "Decompress input")
	dict       = flag.String("dict", "", "Dictionary file for compression/decompression")
	faster     = flag.Bool("faster", false, "Compress faster, but with a minor compression loss")
	slower     = flag.Bool("slower", false, "Compress more, but a lot slower")
	help       = flag.Bool("help", false, "Display help")
)

func main() {
	flag.Parse()

	if *help || (!*compress && !*decompress) || (*compress && *decompress) || (*faster && *slower) {
		fmt.Fprintf(os.Stderr, "s2cp - S2 compression/decompression utility\n\n")
		fmt.Fprintf(os.Stderr, "Usage: s2cp [-c|-d] [-dict dictionary.dict] < input > output\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		os.Exit(1)
	}

	// Load dictionary if specified
	var dictionary *s2.Dict
	if *dict != "" {
		dictData, err := os.ReadFile(*dict)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading dictionary: %v\n", err)
			os.Exit(1)
		}
		dictionary = s2.NewDict(dictData)
		if dictionary == nil {
			fmt.Fprintf(os.Stderr, "Failed to create dictionary from %s\n", *dict)
			os.Exit(1)
		}
	}

	// Read all input
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	var output []byte
	if *compress {
		// Compress
		if dictionary != nil {
			if *faster {
				output = dictionary.Encode(nil, input)
			} else if *slower {
				output = dictionary.EncodeBest(nil, input)
			} else {
				output = dictionary.EncodeBetter(nil, input)
			}
		} else {
			if *faster {
				output = s2.Encode(nil, input)
			} else if *slower {
				output = s2.EncodeBest(nil, input)
			} else {
				output = s2.EncodeBetter(nil, input)
			}
		}
	} else {
		// Decompress
		if dictionary != nil {
			output, err = dictionary.Decode(nil, input)
		} else {
			output, err = s2.Decode(nil, input)
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error decompressing: %v\n", err)
			os.Exit(1)
		}
	}

	// Write output
	_, err = os.Stdout.Write(output)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing output: %v\n", err)
		os.Exit(1)
	}
}
