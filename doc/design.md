Configuration files API is a library written in ruby intended for accessing various configuration files. It is structured into several layers and creates an internal abstraction of configuration file.

## Bottom layer: File access ##

Is responsible for accessing configuration files itself. In simplest case it accesses local configuration files, but it can be adapted to access remote, chrooted or memory files too.

## Middle layer: Parser ##

This layer parses the configuration file which was loaded by the underlying layer. It knows structure of the file and transforms it into abstract representation. The library typically uses external tool for parsing here like Augeas. So, if the external tools has a specific requirements, it has to be satisfied to get things working. For example if the Augeas is in use you need to provide him with a proper lens to parse the particular configuration file.

## Top layer: Configuration file model ##

Last layer creates a model of the configuration file – an API for accessing configuration from an application. It basically creates "an abstraction on top of another abstraction". It means that is unifies use of various tools which can be used for accessing and parsing various configuration files.

## Limitations ##

The approach as described above has several limitations.

### Third party tools dependencies ###

Firstly you need to feed a parser too (e.g. provide lenses for Augeas as described above). So, you at least has to know which parser is used for parsing which file and provide him with all stuff needed for parsing of file of your interest. This is especially important in case of nonstandard / custom configuration files. However this is limitation mainly for developer. If the developer plans to use CFA, then he has to evaluate if some work in this area has to be done as well.

### External tools: masking different results ###

Second example of limitation is that the library and / or parsers on second layer use an abstraction for representing configuration file. This abstraction transform a configuration file into a model and establishes a relation between the file and the model. This relation is not bijective (typical example is Augeas). It means that some irrelevant pieces of the configuration file are not represented in the model. For example some spaces can be left out if these are not needed from syntactic point of view. This can lead to loose of custom padding. Another example can be comments. You can often see that, if your file uses e.g. "#" as a comment mark, then some parsers can squash lines full of these marks (which some developers use as a kind of delimiter) to just one "#". Concrete example for comment marks issue in Augeas is that some lenses do not store initial comment marks in the model. Especially lenses for files where several different comment marks are allowed behaves this way. However, some lenses returns comment including its mark at the beginning, so you need to take care of it in some of CFA's and / or application's layer above the parsing one.

Last but not least example is that some parsers use concept of default values when adding new key with not defined value. This can of course lead to some inconsistencies in configuration file's look.
