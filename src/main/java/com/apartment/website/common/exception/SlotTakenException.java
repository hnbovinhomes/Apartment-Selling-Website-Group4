package com.apartment.website.common.exception;

/** Khung giờ đã có người đặt trước. */
public class SlotTakenException extends RuntimeException {
    public SlotTakenException() {
        super("Khung giờ này đã có người đặt");
    }
}
