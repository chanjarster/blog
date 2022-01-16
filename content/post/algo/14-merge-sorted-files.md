---
title: "算法 - 合并若干有序文件"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2019-02-25T11:25:10+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 12 | 排序（下）][1]

问题描述：现在你有 10 个接口访问日志文件，每个日志文件大小约 300MB，每个文件里的日志都是按照时间戳从小到大排序的。你希望将这 10 个较小的日志文件，合并为 1 个日志文件，合并之后的日志仍然按照时间戳从小到大排列。如果处理上述排序任务的机器内存只有 1GB，你有什么好的解决思路，能“快速”地将这 10 个日志文件合并吗？

思路：其实就是归并排序的里的归并步骤，只不过从归并两个数组变成了归并多个数组。PS. 看这类问题的时候一定仔细看看空间限制条件，不要被吓到也不要随意做判断。

代码：

```java
public class MergeSortedFiles {
  public static void merge(List<FileIterator> fileIteratorList) {

    FileWriter fileWriter = null;

    // 记录还没有遍历结束的文件
    List<FileIterator> notEndingFileIterators = new ArrayList<>(fileIteratorList);

    while (!notEndingFileIterators.isEmpty()) {

      FileIterator min = getMin(notEndingFileIterators);
      fileWriter.writeLine(min.getLine());

      if (!min.nextLine()) {
        // 该文件已经遍历到尾了，将其移除
        notEndingFileIterators.remove(min);
      }

    }
  }

  private static FileIterator getMin(List<FileIterator> notEndingFileIterators) {

    FileIterator min = null;

    for (FileIterator fi : notEndingFileIterators) {
      if (min == null) {
        min = fi;
        continue;
      }

      if (fi.getLine().compareTo(min.getLine()) < 0) {
        min = fi;
      }
    }
    return min;
  }
}

/**
 * 这里不做实现，只表达意思
 */
interface FileIterator {
  /**
   * 返回当前行
   *
   * @return
   */
  String getLine();

  /**
   * 前进到下一行
   *
   * @return 如果已经是最后一行了，返回false。否则返回true。
   */
  boolean nextLine();
}

/**
 * 这里不做实现，只表达意思
 */
interface FileWriter {
  /**
   * 写一行到文件中
   *
   * @param line
   */
  void writeLine(String line);
}
```

算法复杂度分析：

* 不存在最好最坏情况，因为遍历次数是固定的。
* 总行数n、文件数k、每个文件行数m，如果数据特征正好能够达成每次把一个文件遍历完再遍历其余的，那么遍历次数是 `m*k + m*(k-1) + m*(k-2) + ... + m*1 = m*(k*(k+1)/2)`，把`m=n/k`代入得到，`n(k+1)/2`，为O(n)。


[1]: https://time.geekbang.org/column/article/41913
[merge-sort]: ../11-merge-sort