#ifndef CURVATUREINPUTFILTER_H
#define CURVATUREINPUTFILTER_H

#include <QObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqml.h>

class CurvatureInputFilter : public QObject {
    Q_OBJECT
    Q_PROPERTY(QQuickItem* targetItem READ targetItem WRITE setTargetItem NOTIFY targetItemChanged)
    Q_PROPERTY(qreal curvature READ curvature WRITE setCurvature NOTIFY curvatureChanged)

public:
    explicit CurvatureInputFilter(QObject *parent = nullptr);

    QQuickItem* targetItem() const;
    void setTargetItem(QQuickItem* item);

    qreal curvature() const;
    void setCurvature(qreal c);

signals:
    void targetItemChanged();
    void curvatureChanged();

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private:
    QPointF distortPoint(const QPointF &pos, const QSizeF &size) const;
    void installFilter();
    void removeFilter();

    QQuickItem* m_targetItem = nullptr;
    QQuickWindow* m_window = nullptr;
    qreal m_curvature = 0.0;
    bool m_processing = false;
};

#endif // CURVATUREINPUTFILTER_H
