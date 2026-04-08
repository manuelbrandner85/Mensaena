'use client'

import { useRef, useState, useEffect, useCallback, ReactNode } from 'react'

interface VirtualListProps<T> {
  items: T[]
  /** Height of each item in px. Can be a fixed number or 'auto' */
  itemHeight: number
  /** Number of extra items to render above/below viewport. Default 5 */
  buffer?: number
  /** Render function for each item */
  renderItem: (item: T, index: number) => ReactNode
  /** Container height CSS. Default '100%' */
  height?: string
  className?: string
}

/**
 * Lightweight virtual scrolling for long lists.
 * Renders only visible items + buffer to reduce DOM nodes.
 */
export default function VirtualList<T>({
  items,
  itemHeight,
  buffer = 5,
  renderItem,
  height = '100%',
  className,
}: VirtualListProps<T>) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [scrollTop, setScrollTop] = useState(0)
  const [containerHeight, setContainerHeight] = useState(0)

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const observer = new ResizeObserver(([entry]) => {
      setContainerHeight(entry.contentRect.height)
    })
    observer.observe(el)

    return () => observer.disconnect()
  }, [])

  const handleScroll = useCallback(() => {
    if (containerRef.current) {
      setScrollTop(containerRef.current.scrollTop)
    }
  }, [])

  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    el.addEventListener('scroll', handleScroll, { passive: true })
    return () => el.removeEventListener('scroll', handleScroll)
  }, [handleScroll])

  const totalHeight = items.length * itemHeight
  const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - buffer)
  const endIndex = Math.min(
    items.length,
    Math.ceil((scrollTop + containerHeight) / itemHeight) + buffer
  )

  const visibleItems = items.slice(startIndex, endIndex)
  const offsetY = startIndex * itemHeight

  return (
    <div
      ref={containerRef}
      className={className}
      style={{ height, overflow: 'auto', position: 'relative' }}
    >
      <div style={{ height: totalHeight, position: 'relative' }}>
        <div style={{ transform: `translateY(${offsetY}px)` }}>
          {visibleItems.map((item, i) => (
            <div key={startIndex + i} style={{ height: itemHeight }}>
              {renderItem(item, startIndex + i)}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
