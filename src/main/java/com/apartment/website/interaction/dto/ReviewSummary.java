package com.apartment.website.interaction.dto;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * JavaBean: tổng hợp đánh giá của 1 căn: điểm trung bình, số lượt, và số lượt theo từng mức sao (để vẽ thanh 5★ ... 1★).
 * JSP đọc qua getter: ${reviewSummary.averageText} -> getAverageText().
 */
public class ReviewSummary {
    private double average;
    private int count;
    private List<StarRow> rows = new ArrayList<StarRow>();

    public ReviewSummary() {
    }

    public double getAverage() {
        return average;
    }

    public void setAverage(double average) {
        this.average = average;
    }

    public int getCount() {
        return count;
    }

    public void setCount(int count) {
        this.count = count;
    }

    public List<StarRow> getRows() {
        return rows;
    }

    public void setRows(List<StarRow> rows) {
        this.rows = rows;
    }

    /** 4.666 -> "4.7" */
    public String getAverageText() {
        return String.format(Locale.US, "%.1f", average);
    }

    /** Làm tròn điểm trung bình thành chuỗi sao: 4.3 -> "★★★★☆" */
    public String getStars() {
        int full = (int) Math.round(average);
        StringBuilder stars = new StringBuilder();
        for (int i = 1; i <= 5; i++) {
            if (i <= full) {
                stars.append("★");
            } else {
                stars.append("☆");
            }
        }
        return stars.toString();
    }

    /** JavaBean: 1 dòng "5★ ▓▓▓▓░ 3": star = số sao, count = số lượt, percent = độ dài thanh (0-100). */
    public static class StarRow {
        private int star;
        private int count;
        private int percent;

        public StarRow() {
        }

        public int getStar() {
            return star;
        }

        public void setStar(int star) {
            this.star = star;
        }

        public int getCount() {
            return count;
        }

        public void setCount(int count) {
            this.count = count;
        }

        public int getPercent() {
            return percent;
        }

        public void setPercent(int percent) {
            this.percent = percent;
        }
    }
}
