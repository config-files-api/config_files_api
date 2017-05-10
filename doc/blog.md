As you already know, YaST was converted from YCP to Ruby some time ago. At least we repeat it quite often ;-) However, this conversion was done on language basis. Some old design decisions and principles stayed. One of them is usage of SCR for accessing underlying configuration files.

SCR was designed together with YaST. It uses concept of "agents" for accessing configuration files. These agents contains a description of configuration file using own format. Moreover SCR offers location transparency. You can e.g. work with a file in system or in a chrooted environment. However, this piece of code is proprietary and limited by different quality of agents. It is also written in C++ and development is done only in SUSE. And sadly, it is not designed very well. You cannot easily use just the parser or location transparency. You always have to go through complete SCR stack when parsing an input. Similarly, when using location transparency (setting new location), all subsequent SCR calls are influenced by this. From this and some other reasons we decided to replace proprietary SCR with something else. We started to use "Configuration files API"

[Configuration files API][1] (CFA) is a library written in ruby intended for accessing various configuration files. You can download it from [rubygems.org][2], or it is already available in build service for [OpenSUSE 42.3][3]. It is structured into several layers and creates an internal abstraction of configuration file. It has again been designed and developed in SUSE's YaST team. However this time it uses (or can use) third party parsers. CFA provides location transparency for the parser on the bottom layer and unified API for application on the top one. Location transparency is achieved by a well known File interface, so you can use any piece of code which implements the interface here. Implementing support for a new parser is a bit more complicated. In worst case you may need to implement a ruby bindings. However, once you have a bindings, implementing other pieces which are needed to get things working in CFA's stack is simple.

[1]: https://github.com/config-files-api/config_files_api
[2]: https://rubygems.org/gems/cfa
[3]: https://build.opensuse.org/package/show/openSUSE:Leap:42.3/rubygem-cfa

Lets go through layers in details.

## Bottom layer: File access ##

Is responsible for accessing configuration files itself. In simplest case it accesses local configuration files, but it can be adapted to access remote, chrooted or memory files too.

## Middle layer: Parser ##

This layer parses the configuration file which was loaded by the underlying layer. It knows structure of the file and transforms it into abstract representation. The library typically uses external tool for parsing here like Augeas. So, if the external tools has a specific requirements, it has to be satisfied to get things working. For example if the Augeas is in use you need to provide him with a proper lens to parse the particular configuration file.

## Top layer: Configuration file model ##

Last layer creates a model of the configuration file - an API for accessing configuration from an application. It basically creates "an abstraction on top of another abstraction". It means that is unifies use of various tools which can be used for accessing and parsing various configuration files.

## Limitations ##

The approach as described above has several limitations, which is good to know.

### Feed the beast ###

Firstly you need to feed a parser too (e.g. provide lenses for Augeas as described above). So, you at least has to know which parser is used for parsing which file and provide him with all stuff needed for parsing of file of your interest. This is especially important in case of nonstandard / custom configuration files. However this is limitation mainly for developer. If the developer plans to use CFA, then he has to evaluate if some work in this area has to be done as well.

### Beat the beast ###

Second example of limitation is that the library and / or parsers on second layer use an abstraction for representing configuration file. This abstraction transform a configuration file into a model and establishes a relation between the file and the model. This relation is not bijective (typical example is Augeas). It means that some irrelevant pieces of the configuration file are not represented in the model. For example some spaces can be left out if these are not needed from syntactic point of view. This can lead to loose of custom padding. Another example can be comments. You can often see that, if your file uses e.g. "#" as a comment mark, then some parsers can squash lines full of these marks (which some developers use as a kind of delimiter) to just one "#". Concrete example for comment marks issue in Augeas is that some lenses do not store initial comment marks in the model. Especially lenses for files where several different comment marks are allowed behaves this way. However, some lenses returns comment including its mark at the beginning, so you need to take care of it in some of CFA's and / or application's layer above the parsing one.

Last but not least example is that some parsers use concept of default values when adding new key with not defined value. This can of course lead to some inconsistencies in configuration file's look.

## Practical example

As was already written, CFA is being used as a replacement for old fashioned SCR in YaST. We can look at replacing of ```/etc/hosts``` processing in yast2-network closer. Leaving aside a fact that the code is much better readable, we have a performance numbers too. The test was run with ```/etc/hosts``` with 10.000 entries. The test was done using YaST's command line interface and measured using common time utility. However, command line interface do not currently support entering hosts entries. That's why only read was tested.

time | SCR | CFA
--- | --- | ---
real | 1m15.735s | 0m19.079s
user | 1m15.076s | 0m18.348s
sys | 0m0.164s | 0m0.244s

As you can see this part of code is now approximately four times faster then before. Since the practical results looks that promising. The CFA's code is better designed and much better test covered, we in YaST team invest into both - CFA development and conversion of YaST's code from SCR to CFA.
