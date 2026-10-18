package com.apartment.website.property.dto;

/**
 * JavaBean: 1 nút trong thanh phân trang « 1 … 4 5 6 … 12 ».
 * href = null nghĩa là không bấm được (« ở trang đầu, » ở trang cuối, dấu …).
 * list.jsp đọc: ${it.label}, ${it.href}, ${it.active}.
 */
public class PageLink {
    private String label;
    private String href;
    private boolean active;

    public PageLink() {
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public String getHref() {
        return href;
    }

    public void setHref(String href) {
        this.href = href;
    }

    /** Trang đang xem. */
    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }
}
