// Swift Class Dumper

#include <llvm/Object/ObjectFile.h>
#include <llvm/Object/MachO.h>
#include <llvm/Object/MachOUniversal.h>
#include <fstream>
#include <sstream>
#include <vector>
#include <map>
#include <sys/stat.h>
#include <iostream>
#include <array>

using namespace llvm;
using namespace object;

struct SDClass;
struct SDClass {
	std::string name;
	std::vector<SDClass*> classes;
	std::vector<std::string> methods;
};

static bool isOutputSimplified = false;
static bool isOutputCompact = false;
static std::stringstream output;

void createSwiftHeaderFiles(std::vector<SDClass*> classes);

int ctoi(char i) {
	return i - '0';
}

//Inspired by https://www.jeremymorgan.com/tutorials/c-programming/how-to-capture-the-output-of-a-linux-command-in-c/
std::string exec(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    FILE * pipe = popen(cmd, "r");
    if (pipe) {
    	while (!feof(pipe))
    	if (fgets(buffer.data(), buffer.size(), pipe) != nullptr) result+=buffer.data();
    		pclose(pipe);
	}
    return result;
}

std::string classNameFromMangledSymbolString(const char *mangl) {
	// yes, these are all really gross. Sorry.
	// this doesn't handle nesting properly. move to using swift lib functions.
	
	int len = 0;
	int numLen = 0;
	bool hasNamespace = false;
	
	for (size_t i = 0; i < strlen(mangl); i++) {
		switch (mangl[i]) {
			case '_': {
				break;
			}
				
			default: {
				if (isdigit(mangl[i])) {
					numLen++;
					len = 10 * len;
					len += ctoi(mangl[i]);
				}
				else if (len > 0) {
					// we've already read in some digits, now it's over. reset vars too
					if (hasNamespace) {
						char *buf = (char *)malloc(len + 1);
						
						for (int j = 0; j < len; j++) {
							buf[j] = mangl[i + j];
						}
						
						buf[len] = '\0';
						
						return std::string(buf);
					}
					else {
						len = 0;
						numLen = 0;
						hasNamespace = true;
					}
				}
				break;
			}
		}
	}
	
	return std::string("");
}

std::string namespaceFromMangledSymbolString(const char *mangl) {
	// this doesn't handle nesting properly. move to using swift lib functions.
	
	int len = 0;
	int numLen = 0;
	
	for (size_t i = 0; i < strlen(mangl); i++) {
		switch (mangl[i]) {
			case '_': {
				break;
			}
				
			default: {
				if (isdigit(mangl[i])) {
					numLen++;
					len = 10 * len;
					len += ctoi(mangl[i]);
				}
				else if (len > 0) {
					// we've already read in some digits, now it's over. reset vars too
					
					char *buf = (char *)malloc(len + 1);
					
					for (int j = 0; j < len; j++) {
						buf[j] = mangl[i + j];
					}
					
					buf[len] = '\0';
					
					return std::string(buf);
				}
				break;
			}
		}
	}
	
	return std::string("");
}

std::string signatureFromMangledSymbolString(const char *manl) {
	std::string ret = manl;

	return ret;
}

std::string demangle() {
	std::string manl = output.str();
	std::string commandStart = "echo '";
	std::string commandEnd = "' | xcrun swift-demangle ";

	if(isOutputCompact)         commandEnd += "-compact ";
	else if(isOutputSimplified) commandEnd += "-simplified ";

	commandStart += manl;
	
	std::string command = commandStart + commandEnd;
	std::string ret = exec(command.c_str());

	return ret;
}

bool isSwiftSymbol(const char *mangl) {
	//https://github.com/apple/swift/blob/master/docs/ABI/Mangling.rst
	return (
		(mangl[0] == '_' && mangl[1] == 'T') || 
	    (mangl[1] == '_' && mangl[2] == 'T') ||
		(mangl[0] == '_' && mangl[1] == '$')
	);
}

void parseMachOSymbols(MachOObjectFile *obj) {
	auto symbs = obj->symbols();
	
	std::map<std::string, SDClass*> classMap;
	
	for (SymbolRef sym : symbs) {
		auto name = sym.getName();
		
		if (!name) {
			continue;
		}
		
		if (isSwiftSymbol(name->data())) {
			
			std::string className = classNameFromMangledSymbolString(name->data());
			std::string methodSignature = signatureFromMangledSymbolString(name->data());
			
			if (!classMap[className]) {
				auto classObj = new SDClass();
				classObj->name = className;
				classMap[className] = classObj;
			}
			
			classMap[className]->methods.push_back(methodSignature);
			
		}
	}
	
	std::vector<SDClass*> v;
	for(std::map<std::string,SDClass*>::iterator it = classMap.begin(); it != classMap.end(); ++it) {
		v.push_back(it->second);
	}
	createSwiftHeaderFiles(v);
}

// Returns string of 4 spaces multiplied by desired number of times
std::string indentation(int times) {
	std::stringstream ss;
	
	for (int i = 0; i < times; ++i) {
		ss << "\t";
	}
	
	return ss.str();
}

// Returns string of content for .swifth file for a class
// Function is recursive
std::string classHeaderContent(SDClass* cls, int indents) {
	std::stringstream ss;
	
	std::string indenting = indentation(indents);
	std::string indentingMeth = indentation(indents+1);
	ss << indenting << "class " << cls->name << " {\n\n";
	
	for (SDClass* cl : cls->classes) {
		ss << classHeaderContent(cl, indents+1) << "\n";
	}
	
	for (std::string str : cls->methods) {
		ss << indentingMeth << str << "\n";
	}
	
	ss << indenting << "}\n\n";
	return ss.str();
}

void createSwiftHeader(SDClass* cls) {
	std::string strContent = classHeaderContent(cls, 0);

	static bool isInfoPrinted = false;
	if(!isInfoPrinted) {
		output << "// \n";
		output << "// Class dump header generated by Swift-Class-Dump\n";
		output << "// \n\n";
		isInfoPrinted = true;
	}
		
	output << strContent;
}

void createSwiftHeaderFiles(std::vector<SDClass*> classes) {
	for(SDClass* cls : classes) {
		createSwiftHeader(cls);
	}
}

int main(int argc, char **argv) {
	if (argc < 2) {
		printf("Not enough params :(\n");
		return 1;
	}
	
	for (int i = 1; i < argc; i++) {
		if (strncmp(argv[i], "-simplified", 11) == 0) {
			isOutputSimplified = true;
		}

		else if (strncmp(argv[i], "-compact", 8) == 0) {
			isOutputCompact = true;
		}
	}
	
	std::string fileName = std::string(argv[1]);
	
	llvm::ErrorOr<std::unique_ptr<llvm::MemoryBuffer>> bufferOrError = llvm::MemoryBuffer::getFileOrSTDIN(fileName);
	
	auto binOrError = createBinary(bufferOrError.get()->getMemBufferRef(), nullptr);
	
	if (!binOrError) {
		printf("Error!\r\n");
		return 1;
	}
	
	Binary &bin = *binOrError.get();
	
	if (SymbolicFile *symbol = dyn_cast<SymbolicFile>(&bin)) {
		// ensure this is a mach-o
		if (MachOObjectFile *macho = dyn_cast<MachOObjectFile>(symbol)) {
			parseMachOSymbols(macho);
			std::cout << demangle();
		}
		else {
			printf("What is this?\r\n");
			return 3;
		}
	}
	
	else if (MachOUniversalBinary *macho = dyn_cast<MachOUniversalBinary>(&bin)) {
		printf("Found mach-o universal %p\r\n", (void *)macho);
		if (MachOObjectFile *macho = dyn_cast<MachOObjectFile>(symbol)) {
			parseMachOSymbols(macho);
			std::cout << demangle();
		}
		else {
			printf("What is this?\r\n");
			return 3;
		}
	}
	
	else if (Archive *archiv = dyn_cast<Archive>(&bin)) {
		printf("Found archive %p\r\n", (void *)archiv);
	}
	
	else {
		printf("This is not a mach-o! :(\r\n");
	}
	
	return 0;
}
