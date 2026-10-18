package com.apartment.website.property.dto;

import java.util.ArrayList;
import java.util.List;

/** JavaBean: một trang kết quả + tổng số bản ghi (để vẽ phân trang và dòng "hiển thị 1–12"). */
public class PageResult<T> {
    private List<T> items = new ArrayList<T>();
    private long total;
    private int page;
    private int size;

    public PageResult() {
    }

    public List<T> getItems() {
        return items;
    }

    public void setItems(List<T> items) {
        this.items = items;
    }

    public long getTotal() {
        return total;
    }

    public void setTotal(long total) {
        this.total = total;
    }

    public int getPage() {
        return page;
    }

    public void setPage(int page) {
        this.page = page;
    }

    public int getSize() {
        return size;
    }

    public void setSize(int size) {
        this.size = size;
    }

    /** Số trang = làm tròn lên (total / size), ít nhất là 1 trang. */
    public int getTotalPages() {
        if (size <= 0) {
            return 1;
        }
        long pages = (total + size - 1) / size;
        if (pages < 1) {
            return 1;
        }
        return (int) pages;
    }

    /** Thứ tự căn đầu tiên của trang này ("hiển thị 13–24": from = 13). */
    public long getFrom() {
        if (total == 0) {
            return 0;
        }
        return (long) (page - 1) * size + 1;
    }

    /** Thứ tự căn cuối cùng của trang này. */
    public long getTo() {
        long to = (long) page * size;
        if (to > total) {
            to = total;
        }
        return to;
    }
}
