#include "curvatureinputfilter.h"

#include <QEvent>
#include <QMouseEvent>
#include <QHoverEvent>
#include <QWheelEvent>
#include <QCoreApplication>

CurvatureInputFilter::CurvatureInputFilter(QObject *parent)
    : QObject(parent)
{
}

QQuickItem* CurvatureInputFilter::targetItem() const
{
    return m_targetItem;
}

void CurvatureInputFilter::setTargetItem(QQuickItem* item)
{
    if (m_targetItem == item)
        return;

    if (m_targetItem) {
        disconnect(m_targetItem, &QQuickItem::windowChanged, this, &CurvatureInputFilter::installFilter);
        removeFilter();
    }

    m_targetItem = item;

    if (m_targetItem) {
        connect(m_targetItem, &QQuickItem::windowChanged, this, &CurvatureInputFilter::installFilter);
        installFilter();
    }

    emit targetItemChanged();
}

qreal CurvatureInputFilter::curvature() const
{
    return m_curvature;
}

void CurvatureInputFilter::setCurvature(qreal c)
{
    if (qFuzzyCompare(m_curvature, c))
        return;
    m_curvature = c;
    emit curvatureChanged();
}

void CurvatureInputFilter::installFilter()
{
    QQuickWindow* newWindow = m_targetItem ? m_targetItem->window() : nullptr;

    if (m_window == newWindow)
        return;

    removeFilter();
    m_window = newWindow;

    if (m_window)
        m_window->installEventFilter(this);
}

void CurvatureInputFilter::removeFilter()
{
    if (m_window) {
        m_window->removeEventFilter(this);
        m_window = nullptr;
    }
}

QPointF CurvatureInputFilter::distortPoint(const QPointF &pos, const QSizeF &size) const
{
    // Normalize to [0, 1] — same coordinate space as the GLSL distortCoordinates()
    qreal nx = pos.x() / size.width();
    qreal ny = pos.y() / size.height();

    qreal ccx = nx - 0.5;
    qreal ccy = ny - 0.5;
    qreal dist = (ccx * ccx + ccy * ccy) * m_curvature;

    qreal rx = nx + ccx * (1.0 + dist) * dist;
    qreal ry = ny + ccy * (1.0 + dist) * dist;

    // De-normalize back to pixel coordinates
    return QPointF(rx * size.width(), ry * size.height());
}

bool CurvatureInputFilter::eventFilter(QObject *obj, QEvent *event)
{
    Q_UNUSED(obj)

    if (m_curvature <= 0.0 || m_processing || !m_window)
        return false;

    QSizeF winSize(m_window->width(), m_window->height());
    if (winSize.isEmpty())
        return false;

    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseMove:
    case QEvent::MouseButtonDblClick: {
        QMouseEvent *me = static_cast<QMouseEvent*>(event);
        QPointF remapped = distortPoint(me->position(), winSize);
        QMouseEvent newEvent(me->type(), remapped,
                             remapped + me->globalPosition() - me->position(),
                             me->button(), me->buttons(), me->modifiers(),
                             me->pointingDevice());
        m_processing = true;
        QCoreApplication::sendEvent(m_window, &newEvent);
        m_processing = false;
        return true;
    }
    case QEvent::HoverMove:
    case QEvent::HoverEnter:
    case QEvent::HoverLeave: {
        QHoverEvent *he = static_cast<QHoverEvent*>(event);
        QPointF remapped = distortPoint(he->position(), winSize);
        QPointF remappedOld = distortPoint(he->oldPos(), winSize);
        QPointF globalRemapped = remapped + he->globalPosition() - he->position();
        QHoverEvent newEvent(he->type(), remapped, globalRemapped, remappedOld,
                             he->modifiers(), he->pointingDevice());
        m_processing = true;
        QCoreApplication::sendEvent(m_window, &newEvent);
        m_processing = false;
        return true;
    }
    case QEvent::Wheel: {
        QWheelEvent *we = static_cast<QWheelEvent*>(event);
        QPointF remapped = distortPoint(we->position(), winSize);
        QWheelEvent newEvent(remapped,
                             remapped + we->globalPosition() - we->position(),
                             we->pixelDelta(), we->angleDelta(),
                             we->buttons(), we->modifiers(), we->phase(),
                             we->isInverted(), we->source(),
                             we->pointingDevice());
        m_processing = true;
        QCoreApplication::sendEvent(m_window, &newEvent);
        m_processing = false;
        return true;
    }
    default:
        break;
    }

    return false;
}
