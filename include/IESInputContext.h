#import <Foundation/Foundation.h>

// Isaac's render view itself implements UIKeyInput in normal gameplay.
BOOL IESHasTextInput(id root, Class gameViewClass, Protocol *keyInput, Protocol *textInput);
