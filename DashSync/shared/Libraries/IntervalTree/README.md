## RHIntervalTree

An Objective-C implementation of a Centred Interval Tree.

RHIntervalTree provides an Objective-C wrapper around an internal C++ Interval Tree implementation by [Erik Garrison](https://github.com/ekg/intervaltree/).



## Overview
An interval tree can be used to efficiently find a set of numeric
intervals overlapping or containing another interval, for example a view containing overlapping calendar events for a given day or week.

They can also be used for windowing queries, for instance, to find all roads on a computerised map inside a rectangular viewport, or to find all visible elements inside a three-dimensional scene.

[Read More](http://en.wikipedia.org/wiki/Interval_tree)

## Classes
* RHIntervalTree - main interface to the Interval Tree.
* RHInterval - convenience container class for objects passed into the Interval Tree.
* RHIntervalProtocol - RHInterval implements this protocol, so can you.


## Getting Started
Include RHIntervalTree.h in your project. (RHIntervalTree.mm is a Objective-C++ file hence its extension)


```objectivec
#import <RHIntervalTree.h>
```


Setting up a tree.

```objectivec
NSArray *intervals = [NSArray arrayWithObjects:
                     [RHInterval intervalWithRange:NSMakeRange(5, 3) object:@"one"],
                     [RHInterval intervalWithRange:NSMakeRange(7, 100) object:@"two"],
                     [RHInterval intervalWithRange:NSMakeRange(5, 5) object:@"three"],
                     [RHInterval intervalWithRange:NSMakeRange(2, 8) object:@"four"],
                     nil];

RHIntervalTree *tree = [[RHIntervalTree alloc] initWithIntervalObjects:intervals];
        
```

Performing a query

```objectivec
NSArray *overlappingObjects = [tree overlappingObjectsBetweenStart:77 andStop:220];

```

## Interface

```objectivec

@interface RHIntervalTree : NSObject

-(id)initWithIntervalObjects:(NSArray*)intervals; //all added objects should implement the RHIntervalProtocol

-(NSInteger)minStart;
-(NSInteger)maxStop;

-(NSArray*)allObjects;

//Contained methods return objects fully contained within the start and stop(inclusive) coordinates.
-(NSArray*)containedObjectsInRange:(NSRange)range;
-(NSArray*)containedObjectsBetweenStart:(NSInteger)start andStop:(NSInteger)stop;

//Overlapping methods return objects which are contained or partially overlap the start and stop(inclusive) coordinates.
-(NSArray*)overlappingObjectsInRange:(NSRange)range;
-(NSArray*)overlappingObjectsBetweenStart:(NSInteger)start andStop:(NSInteger)stop;

@end

```

## Licence

###RHIntervalTree
Released under the Modified BSD License. (Attribution Required)
<pre>
RHIntervalTree

Copyright (c) 2013 Richard Heard. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>


###IntervalTree.h
Released under the MIT Licence.
<pre>
IntervalTree.h

Copyright (c) 2011 Erik Garrison

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
</pre>
