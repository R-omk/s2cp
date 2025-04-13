# S2CP - Fast Compression with Dictionary Support

S2CP is a high-performance compression library based on S2 compression algorithm, an extension of Snappy, with added dictionary support for improved compression ratios.

### S2 Compression

For detailed instructions on using S2 compression, see:
[S2 Documentation](https://github.com/klauspost/compress/tree/master/s2)

### Dictionary Building

For instructions on building and using dictionaries, see:
[Dictionary Builder Documentation](https://github.com/klauspost/compress/tree/master/dict)

### Usage Example

Basic workflow with dictionary compression:

```bash
# Install dictionary builder
go install github.com/klauspost/compress/dict/cmd/builddict@latest

# Build dictionary from sample files
builddict -format s2 -len 65536 -o my.s2dict samples/

# Install s2cp
go install github.com/R-omk/s2cp@latest

# Compress file using dictionary
cat myfile | s2cp -c -slower -dict my.s2dict > myfile.s2
```

