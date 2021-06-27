//
//  IntervalTree.h
//
//  Created by Erik Garrison.
//  Copyright (c) 2011 Erik Garrison. All rights reserved
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

//sourced from https://github.com/ekg/intervaltree/blob/master/IntervalTree.h on 28/02/2013

#ifndef __INTERVAL_TREE_H
#define __INTERVAL_TREE_H

#include <algorithm>
#include <iostream>
#include <vector>

using namespace std;

template <class T, typename K = long>
class Interval {
  public:
	K start;
	K stop;
	T value;
	Interval(K s, K e, const T &v)
	    : start(s), stop(e), value(v) {
	}
};

template <class T, typename K = long>
long intervalStart(const Interval<T, K> &i) {
	return i.start;
}

template <class T, typename K = long>
long intervalStop(const Interval<T, K> &i) {
	return i.stop;
}

template <class T, typename K = long>
ostream &operator<<(ostream &out, Interval<T, K> &i) {
	out << "Interval(" << i.start << ", " << i.stop << "): " << i.value;
	return out;
}

template <class T, typename K = long>
class IntervalStartSorter {
  public:
	bool operator()(const Interval<T, K> &a, const Interval<T, K> &b) {
		return a.start < b.start;
	}
};

template <class T, typename K = long>
class IntervalTree {

  public:
	typedef Interval<T, K> interval;
	typedef vector<interval> intervalVector;
	typedef IntervalTree<T, K> intervalTree;

	intervalVector intervals;
	intervalTree *left;
	intervalTree *right;
	long center;

	IntervalTree<T, K>(void)
	    : left(NULL), right(NULL), center(0) {
	}

	IntervalTree<T, K>(const intervalTree &other) {
		center = other.center;
		intervals = other.intervals;
		if (other.left) {
			left = (intervalTree *)malloc(sizeof(intervalTree));
			*left = *other.left;
		} else {
			left = NULL;
		}
		if (other.right) {
			right = new intervalTree();
			*right = *other.right;
		} else {
			right = NULL;
		}
	}

	IntervalTree<T, K> &operator=(const intervalTree &other) {
		center = other.center;
		intervals = other.intervals;
		if (other.left) {
			left = new intervalTree();
			*left = *other.left;
		} else {
			left = NULL;
		}
		if (other.right) {
			right = new intervalTree();
			*right = *other.right;
		} else {
			right = NULL;
		}
		return *this;
	}

	IntervalTree<T, K>(intervalVector &ivals, unsigned int depth = 16, unsigned int minbucket = 64, long leftextent = 0, long rightextent = 0, unsigned int maxbucket = 512)
	    : left(NULL), right(NULL) {

		--depth;
		if (depth == 0 || (ivals.size() < minbucket && ivals.size() < maxbucket)) {
			intervals = ivals;
		} else {
			if (leftextent == 0 && rightextent == 0) {
				// sort intervals by start
				IntervalStartSorter<T, K> intervalStartSorter;
				sort(ivals.begin(), ivals.end(), intervalStartSorter);
			}

			long leftp = 0;
			long rightp = 0;
			long centerp = 0;

			if (leftextent || rightextent) {
				leftp = leftextent;
				rightp = rightextent;
			} else {
				leftp = ivals.front().start;
				vector<K> stops;
				stops.resize(ivals.size());
				transform(ivals.begin(), ivals.end(), stops.begin(), intervalStop<T, K>);
				rightp = *max_element(stops.begin(), stops.end());
			}

			//centerp = ( leftp + rightp ) / 2;
			centerp = ivals.at(ivals.size() / 2).start;
			center = centerp;

			intervalVector lefts;
			intervalVector rights;

			for (typename intervalVector::iterator i = ivals.begin(); i != ivals.end(); ++i) {
				interval &interval = *i;
				if (interval.stop < center) {
					lefts.push_back(interval);
				} else if (interval.start > center) {
					rights.push_back(interval);
				} else {
					intervals.push_back(interval);
				}
			}

			if (!lefts.empty()) {
				left = new intervalTree(lefts, depth, minbucket, leftp, centerp);
			}
			if (!rights.empty()) {
				right = new intervalTree(rights, depth, minbucket, centerp, rightp);
			}
		}
	}

	void findOverlapping(K start, K stop, intervalVector &overlapping) {
		if (!intervals.empty() && !(stop < intervals.front().start)) {
			for (typename intervalVector::iterator i = intervals.begin(); i != intervals.end(); ++i) {
				interval &interval = *i;
				if (interval.stop >= start && interval.start <= stop) {
					overlapping.push_back(interval);
				}
			}
		}

		if (left && start <= center) {
			left->findOverlapping(start, stop, overlapping);
		}

		if (right && stop >= center) {
			right->findOverlapping(start, stop, overlapping);
		}
	}

	void findContained(K start, K stop, intervalVector &contained) {
		if (!intervals.empty() && !(stop < intervals.front().start)) {
			for (typename intervalVector::iterator i = intervals.begin(); i != intervals.end(); ++i) {
				interval &interval = *i;
				if (interval.start >= start && interval.stop <= stop) {
					contained.push_back(interval);
				}
			}
		}

		if (left && start <= center) {
			left->findContained(start, stop, contained);
		}

		if (right && stop >= center) {
			right->findContained(start, stop, contained);
		}
	}

	~IntervalTree(void) {
		// traverse the left and right
		// delete them all the way down
		if (left) {
			delete left;
		}
		if (right) {
			delete right;
		}
	}
};

#endif
