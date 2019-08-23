import 'dart:core';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:mp_flutter_chart/chart/mp/adapter_android_mp.dart';
import 'package:mp_flutter_chart/chart/mp/color.dart';
import 'package:mp_flutter_chart/chart/mp/core/axis.dart';
import 'package:mp_flutter_chart/chart/mp/core/format.dart';
import 'package:mp_flutter_chart/chart/mp/core/highlight.dart';
import 'package:mp_flutter_chart/chart/mp/core/interfaces.dart';
import 'package:mp_flutter_chart/chart/mp/core/legend.dart';
import 'package:mp_flutter_chart/chart/mp/core/range.dart';
import 'package:mp_flutter_chart/chart/mp/core/render.dart';
import 'package:mp_flutter_chart/chart/mp/mode.dart';
import 'package:mp_flutter_chart/chart/mp/painter/pie_chart_painter.dart';
import 'package:mp_flutter_chart/chart/mp/painter/scatter_chart_painter.dart';
import 'package:mp_flutter_chart/chart/mp/poolable/point.dart';
import 'package:mp_flutter_chart/chart/mp/util.dart';

abstract class BaseEntry {
  /** the y value */
  double y = 0;

  /** optional spot for additional data this Entry represents */
  Object mData = null;

  /** optional icon image */
  ui.Image mIcon = null;

  BaseEntry({double y, ui.Image icon, Object data}) {
    this.y = y;
    this.mIcon = icon;
    this.mData = data;
  }
}

class Entry extends BaseEntry {
  double x = 0;

  Entry({double x, double y, ui.Image icon, Object data})
      : this.x = x,
        super(y: y, icon: icon, data: data);

  Entry copy() {
    Entry e = Entry(x: x, y: y, data: mData);
    return e;
  }
}

class BarEntry extends Entry {
  /**
   * the values the stacked barchart holds
   */
  List<double> mYVals;

  /**
   * the ranges for the individual stack values - automatically calculated
   */
  List<Range> mRanges;

  /**
   * the sum of all negative values this entry (if stacked) contains
   */
  double mNegativeSum;

  /**
   * the sum of all positive values this entry (if stacked) contains
   */
  double mPositiveSum;

  BarEntry({double x, double y, ui.Image icon, Object data})
      : super(x: x, y: y, icon: icon, data: data);

  BarEntry.fromListYVals(
      {double x, List<double> vals, ui.Image icon, Object data})
      : super(x: x, y: calcSum(vals), icon: icon, data: data) {
    this.mYVals = vals;
    calcPosNegSum();
    calcRanges();
  }

  BarEntry copy() {
    BarEntry copied = BarEntry(x: x, y: y, data: mData);
    copied.setVals(mYVals);
    return copied;
  }

  /**
   * Returns the stacked values this BarEntry represents, or null, if only a single value is represented (then, use
   * getY()).
   *
   * @return
   */
  List<double> getYVals() {
    return mYVals;
  }

  /**
   * Set the array of values this BarEntry should represent.
   *
   * @param vals
   */
  void setVals(List<double> vals) {
    y = calcSum(vals);
    mYVals = vals;
    calcPosNegSum();
    calcRanges();
  }

  /**
   * Returns the ranges of the individual stack-entries. Will return null if this entry is not stacked.
   *
   * @return
   */
  List<Range> getRanges() {
    return mRanges;
  }

  /**
   * Returns true if this BarEntry is stacked (has a values array), false if not.
   *
   * @return
   */
  bool isStacked() {
    return mYVals != null;
  }

  double getSumBelow(int stackIndex) {
    if (mYVals == null) return 0;

    double remainder = 0.0;
    int index = mYVals.length - 1;
    while (index > stackIndex && index >= 0) {
      remainder += mYVals[index];
      index--;
    }

    return remainder;
  }

  /**
   * Reuturns the sum of all positive values this entry (if stacked) contains.
   *
   * @return
   */
  double getPositiveSum() {
    return mPositiveSum;
  }

  /**
   * Returns the sum of all negative values this entry (if stacked) contains. (this is a positive number)
   *
   * @return
   */
  double getNegativeSum() {
    return mNegativeSum;
  }

  void calcPosNegSum() {
    if (mYVals == null) {
      mNegativeSum = 0;
      mPositiveSum = 0;
      return;
    }

    double sumNeg = 0.0;
    double sumPos = 0.0;

    for (double f in mYVals) {
      if (f <= 0.0)
        sumNeg += f.abs();
      else
        sumPos += f;
    }

    mNegativeSum = sumNeg;
    mPositiveSum = sumPos;
  }

  /**
   * Calculates the sum across all values of the given stack.
   *
   * @param vals
   * @return
   */
  static double calcSum(List<double> vals) {
    if (vals == null) return 0.0;
    double sum = 0.0;
    for (double f in vals) sum += f;
    return sum;
  }

  void calcRanges() {
    List<double> values = getYVals();

    if (values == null || values.length == 0) return;

    mRanges = List(values.length);

    double negRemain = -getNegativeSum();
    double posRemain = 0.0;

    for (int i = 0; i < mRanges.length; i++) {
      double value = values[i];

      if (value < 0) {
        mRanges[i] = Range(negRemain, negRemain - value);
        negRemain -= value;
      } else {
        mRanges[i] = Range(posRemain, posRemain + value);
        posRemain += value;
      }
    }
  }
}

class RadarEntry extends Entry {
  RadarEntry({double value, Object data}) : super(x: 0, y: value, data: data);

  /**
   * This is the same as getY(). Returns the value of the RadarEntry.
   *
   * @return
   */
  double getValue() {
    return y;
  }

  RadarEntry copy() {
    RadarEntry e = RadarEntry(value: y, data: mData);
    return e;
  }
}

class BubbleEntry extends Entry {
  /** size value */
  double mSize = 0;

  /**
   * Constructor.
   *
   * @param x The value on the x-axis.
   * @param y The value on the y-axis.
   * @param size The size of the bubble.
   */
  BubbleEntry({double x, double y, double size, Object data, ui.Image icon})
      : super(x: x, y: y, data: data, icon: icon) {
    this.mSize = size;
  }

  BubbleEntry copy() {
    BubbleEntry c = BubbleEntry(x: x, y: y, size: mSize, data: mData);
    return c;
  }

  /**
   * Returns the size of this entry (the size of the bubble).
   *
   * @return
   */
  double getSize() {
    return mSize;
  }

  void setSize(double size) {
    this.mSize = size;
  }
}

class CandleEntry extends Entry {
  /** shadow-high value */
  double mShadowHigh = 0;

  /** shadow-low value */
  double mShadowLow = 0;

  /** close value */
  double mClose = 0;

  /** open value */
  double mOpen = 0;

  CandleEntry(
      {double x,
      double shadowH,
      double shadowL,
      double open,
      double close,
      ui.Image icon,
      Object data})
      : super(x: x, y: (shadowH + shadowL) / 2, icon: icon, data: data) {
    this.mShadowHigh = shadowH;
    this.mShadowLow = shadowL;
    this.mOpen = open;
    this.mClose = close;
  }

  /**
   * Returns the overall range (difference) between shadow-high and
   * shadow-low.
   *
   * @return
   */
  double getShadowRange() {
    return (mShadowHigh - mShadowLow).abs();
  }

  /**
   * Returns the body size (difference between open and close).
   *
   * @return
   */
  double getBodyRange() {
    return (mOpen - mClose).abs();
  }

  CandleEntry copy() {
    CandleEntry c = CandleEntry(
        x: x,
        shadowH: mShadowHigh,
        shadowL: mShadowLow,
        open: mOpen,
        close: mClose,
        data: mData);
    return c;
  }

  /**
   * Returns the upper shadows highest value.
   *
   * @return
   */
  double getHigh() {
    return mShadowHigh;
  }

  void setHigh(double mShadowHigh) {
    this.mShadowHigh = mShadowHigh;
  }

  /**
   * Returns the lower shadows lowest value.
   *
   * @return
   */
  double getLow() {
    return mShadowLow;
  }

  void setLow(double mShadowLow) {
    this.mShadowLow = mShadowLow;
  }

  /**
   * Returns the bodys close value.
   *
   * @return
   */
  double getClose() {
    return mClose;
  }

  void setClose(double mClose) {
    this.mClose = mClose;
  }

  /**
   * Returns the bodys open value.
   *
   * @return
   */
  double getOpen() {
    return mOpen;
  }

  void setOpen(double mOpen) {
    this.mOpen = mOpen;
  }
}

class PieEntry extends Entry {
  String label;

  PieEntry({double value, String label, ui.Image icon, Object data})
      : super(x: 0, y: value, icon: icon, data: data) {
    this.label = label;
  }

  double getValue() {
    return y;
  }

  PieEntry copy() {
    PieEntry e = PieEntry(value: getValue(), label: label, data: mData);
    return e;
  }
}

enum Rounding {
  UP,
  DOWN,
  CLOSEST,
}

abstract class IDataSet<T extends Entry> {
  double getYMin();

  double getYMax();

  double getXMin();

  double getXMax();

  int getEntryCount();

  void calcMinMax();

  void calcMinMaxY(double fromX, double toX);

  T getEntryForXValue1(double xValue, double closestToY, Rounding rounding);

  T getEntryForXValue2(double xValue, double closestToY);

  List<T> getEntriesForXValue(double xValue);

  T getEntryForIndex(int index);

  int getEntryIndex1(double xValue, double closestToY, Rounding rounding);

  int getEntryIndex2(T e);

  int getIndexInEntries(int xIndex);

  bool addEntry(T e);

  void addEntryOrdered(T e);

  bool removeFirst();

  bool removeLast();

  bool removeEntry1(T e);

  bool removeEntryByXValue(double xValue);

  bool removeEntry2(int index);

  bool contains(T entry);

  void clear();

  String getLabel();

  void setLabel(String label);

  AxisDependency getAxisDependency();

  void setAxisDependency(AxisDependency dependency);

  List<ui.Color> getColors();

  ui.Color getColor1();

  GradientColor getGradientColor1();

  List<GradientColor> getGradientColors();

  GradientColor getGradientColor2(int index);

  ui.Color getColor2(int index);

  bool isHighlightEnabled();

  void setHighlightEnabled(bool enabled);

  void setValueFormatter(ValueFormatter f);

  ValueFormatter getValueFormatter();

  bool needsFormatter();

  void setValueTextColor(ui.Color color);

  void setValueTextColors(List<ui.Color> colors);

  void setValueTypeface(TextStyle ts);

  void setValueTextSize(double size);

  ui.Color getValueTextColor1();

  ui.Color getValueTextColor2(int index);

  TextStyle getValueTypeface();

  double getValueTextSize();

  LegendForm getForm();

  double getFormSize();

  double getFormLineWidth();

  DashPathEffect getFormLineDashEffect();

  void setDrawValues(bool enabled);

  bool isDrawValuesEnabled();

  void setDrawIcons(bool enabled);

  bool isDrawIconsEnabled();

  void setIconsOffset(MPPointF offset);

  MPPointF getIconsOffset();

  void setVisible(bool visible);

  bool isVisible();
}

mixin IPieDataSet on IDataSet<PieEntry> {
  /**
   * Returns the space that is set to be between the piechart-slices of this
   * DataSet, in pixels.
   *
   * @return
   */
  double getSliceSpace();

  /**
   * When enabled, slice spacing will be 0.0 when the smallest value is going to be
   *   smaller than the slice spacing itself.
   *
   * @return
   */
  bool isAutomaticallyDisableSliceSpacingEnabled();

  /**
   * Returns the distance a highlighted piechart slice is "shifted" away from
   * the chart-center in dp.
   *
   * @return
   */
  double getSelectionShift();

  ValuePosition getXValuePosition();

  ValuePosition getYValuePosition();

  /**
   * When valuePosition is OutsideSlice, use slice colors as line color if true
   * */
  bool isUsingSliceColorAsValueLineColor();

  /**
   * When valuePosition is OutsideSlice, indicates line color
   * */
  Color getValueLineColor();

  /**
   *  When valuePosition is OutsideSlice, indicates line width
   *  */
  double getValueLineWidth();

  /**
   * When valuePosition is OutsideSlice, indicates offset as percentage out of the slice size
   * */
  double getValueLinePart1OffsetPercentage();

  /**
   * When valuePosition is OutsideSlice, indicates length of first half of the line
   * */
  double getValueLinePart1Length();

  /**
   * When valuePosition is OutsideSlice, indicates length of second half of the line
   * */
  double getValueLinePart2Length();

  /**
   * When valuePosition is OutsideSlice, this allows variable line length
   * */
  bool isValueLineVariableLength();
}

abstract class BaseDataSet<T extends Entry> implements IDataSet<T> {
  /**
   * List representing all colors that are used for this DataSet
   */
  List<ui.Color> mColors = null;

  GradientColor mGradientColor = null;

  List<GradientColor> mGradientColors = null;

  /**
   * List representing all colors that are used for drawing the actual values for this DataSet
   */
  List<ui.Color> mValueColors = null;

  /**
   * label that describes the DataSet or the data the DataSet represents
   */
  String mLabel = "DataSet";

  /**
   * this specifies which axis this DataSet should be plotted against
   */
  AxisDependency mAxisDependency = AxisDependency.LEFT;

  /**
   * if true, value highlightning is enabled
   */
  bool mHighlightEnabled = true;

  /**
   * custom formatter that is used instead of the auto-formatter if set
   */
  ValueFormatter mValueFormatter;

  /**
   * the typeface used for the value text
   */
  TextStyle mValueTypeface;

  LegendForm mForm = LegendForm.DEFAULT;
  double mFormSize = double.nan;
  double mFormLineWidth = double.nan;
  DashPathEffect mFormLineDashEffect = null;

  /**
   * if true, y-values are drawn on the chart
   */
  bool mDrawValues = true;

  /**
   * if true, y-icons are drawn on the chart
   */
  bool mDrawIcons = true;

  /**
   * the offset for drawing icons (in dp)
   */
  MPPointF mIconsOffset = MPPointF(0, 0);

  /**
   * the size of the value-text labels
   */
  double mValueTextSize = 17;

  /**
   * flag that indicates if the DataSet is visible or not
   */
  bool mVisible = true;

  /**
   * Default constructor.
   */
  BaseDataSet() {
    mColors = List();
    mValueColors = List();

    // default color
    mColors.add(ui.Color.fromARGB(255, 140, 234, 255));
    mValueColors.add(ColorUtils.BLACK);
  }

  /**
   * Constructor with label.
   *
   * @param label
   */
  BaseDataSet.withLabel(String label) {
    mColors = List();
    mValueColors = List();

    // default color
    mColors.add(ui.Color.fromARGB(255, 140, 234, 255));
    mValueColors.add(ColorUtils.BLACK);
    this.mLabel = label;
  }

  /**
   * Use this method to tell the data set that the underlying data has changed.
   */
  void notifyDataSetChanged() {
    calcMinMax();
  }

  /**
   * ###### ###### COLOR GETTING RELATED METHODS ##### ######
   */

  @override
  List<ui.Color> getColors() {
    return mColors;
  }

  List<ui.Color> getValueColors() {
    return mValueColors;
  }

  @override
  ui.Color getColor1() {
    return mColors[0];
  }

  @override
  ui.Color getColor2(int index) {
    return mColors[index % mColors.length];
  }

  @override
  GradientColor getGradientColor1() {
    return mGradientColor;
  }

  @override
  List<GradientColor> getGradientColors() {
    return mGradientColors;
  }

  @override
  GradientColor getGradientColor2(int index) {
    return mGradientColors[index % mGradientColors.length];
  }

  /**
   * ###### ###### COLOR SETTING RELATED METHODS ##### ######
   */

  /**
   * Sets the colors that should be used fore this DataSet. Colors are reused
   * as soon as the number of Entries the DataSet represents is higher than
   * the size of the colors array. If you are using colors from the resources,
   * make sure that the colors are already prepared (by calling
   * getResources().getColor(...)) before adding them to the DataSet.
   *
   * @param colors
   */
  void setColors1(List<ui.Color> colors) {
    this.mColors = colors;
  }

  /**
   * Adds a  color to the colors array of the DataSet.
   *
   * @param color
   */
  void addColor(ui.Color color) {
    if (mColors == null) mColors = List();
    mColors.add(color);
  }

  /**
   * Sets the one and ONLY color that should be used for this DataSet.
   * Internally, this recreates the colors array and adds the specified color.
   *
   * @param color
   */
  void setColor1(ui.Color color) {
    resetColors();
    mColors.add(color);
  }

  /**
   * Sets the start and end color for gradient color, ONLY color that should be used for this DataSet.
   *
   * @param startColor
   * @param endColor
   */
  void setGradientColor(ui.Color startColor, ui.Color endColor) {
    mGradientColor = GradientColor(startColor, endColor);
  }

  /**
   * Sets the start and end color for gradient colors, ONLY color that should be used for this DataSet.
   *
   * @param gradientColors
   */
  void setGradientColors(List<GradientColor> gradientColors) {
    this.mGradientColors = gradientColors;
  }

  /**
   * Sets a color with a specific alpha value.
   *
   * @param color
   * @param alpha from 0-255
   */
  void setColor2(ui.Color color, int alpha) {
    setColor1(ui.Color.fromARGB(alpha, color.red, color.green, color.blue));
  }

  /**
   * Sets colors with a specific alpha value.
   *
   * @param colors
   * @param alpha
   */
  void setColors2(List<ui.Color> colors, int alpha) {
    resetColors();
    for (ui.Color color in colors) {
      addColor(ui.Color.fromARGB(alpha, color.red, color.green, color.blue));
    }
  }

  /**
   * Resets all colors of this DataSet and recreates the colors array.
   */
  void resetColors() {
    if (mColors == null) {
      mColors = List();
    }
    mColors.clear();
  }

  /**
   * ###### ###### OTHER STYLING RELATED METHODS ##### ######
   */

  @override
  void setLabel(String label) {
    mLabel = label;
  }

  @override
  String getLabel() {
    return mLabel;
  }

  @override
  void setHighlightEnabled(bool enabled) {
    mHighlightEnabled = enabled;
  }

  @override
  bool isHighlightEnabled() {
    return mHighlightEnabled;
  }

  @override
  void setValueFormatter(ValueFormatter f) {
    if (f == null)
      return;
    else
      mValueFormatter = f;
  }

  @override
  ValueFormatter getValueFormatter() {
    if (needsFormatter()) return Utils.getDefaultValueFormatter();
    return mValueFormatter;
  }

  @override
  bool needsFormatter() {
    return mValueFormatter == null;
  }

  @override
  void setValueTextColor(ui.Color color) {
    mValueColors.clear();
    mValueColors.add(color);
  }

  @override
  void setValueTextColors(List<ui.Color> colors) {
    mValueColors = colors;
  }

  @override
  void setValueTypeface(TextStyle tf) {
    mValueTypeface = tf;
  }

  @override
  void setValueTextSize(double size) {
    mValueTextSize = Utils.convertDpToPixel(size);
  }

  @override
  ui.Color getValueTextColor1() {
    return mValueColors[0];
  }

  @override
  ui.Color getValueTextColor2(int index) {
    return mValueColors[index % mValueColors.length];
  }

  @override
  TextStyle getValueTypeface() {
    return mValueTypeface;
  }

  @override
  double getValueTextSize() {
    return mValueTextSize;
  }

  void setForm(LegendForm form) {
    mForm = form;
  }

  @override
  LegendForm getForm() {
    return mForm;
  }

  void setFormSize(double formSize) {
    mFormSize = formSize;
  }

  @override
  double getFormSize() {
    return mFormSize;
  }

  void setFormLineWidth(double formLineWidth) {
    mFormLineWidth = formLineWidth;
  }

  @override
  double getFormLineWidth() {
    return mFormLineWidth;
  }

  void setFormLineDashEffect(DashPathEffect dashPathEffect) {
    mFormLineDashEffect = dashPathEffect;
  }

  @override
  DashPathEffect getFormLineDashEffect() {
    return mFormLineDashEffect;
  }

  @override
  void setDrawValues(bool enabled) {
    this.mDrawValues = enabled;
  }

  @override
  bool isDrawValuesEnabled() {
    return mDrawValues;
  }

  @override
  void setDrawIcons(bool enabled) {
    mDrawIcons = enabled;
  }

  @override
  bool isDrawIconsEnabled() {
    return mDrawIcons;
  }

  @override
  void setIconsOffset(MPPointF offsetDp) {
    mIconsOffset.x = offsetDp.x;
    mIconsOffset.y = offsetDp.y;
  }

  @override
  MPPointF getIconsOffset() {
    return mIconsOffset;
  }

  @override
  void setVisible(bool visible) {
    mVisible = visible;
  }

  @override
  bool isVisible() {
    return mVisible;
  }

  @override
  AxisDependency getAxisDependency() {
    return mAxisDependency;
  }

  @override
  void setAxisDependency(AxisDependency dependency) {
    mAxisDependency = dependency;
  }

  /**
   * ###### ###### DATA RELATED METHODS ###### ######
   */

  @override
  int getIndexInEntries(int xIndex) {
    for (int i = 0; i < getEntryCount(); i++) {
      if (xIndex == getEntryForIndex(i).x) return i;
    }

    return -1;
  }

  @override
  bool removeFirst() {
    if (getEntryCount() > 0) {
      T entry = getEntryForIndex(0);
      return removeEntry1(entry);
    } else
      return false;
  }

  @override
  bool removeLast() {
    if (getEntryCount() > 0) {
      T e = getEntryForIndex(getEntryCount() - 1);
      return removeEntry1(e);
    } else
      return false;
  }

  @override
  bool removeEntryByXValue(double xValue) {
    T e = getEntryForXValue2(xValue, double.nan);
    return removeEntry1(e);
  }

  @override
  bool removeEntry2(int index) {
    T e = getEntryForIndex(index);
    return removeEntry1(e);
  }

  @override
  bool contains(T e) {
    for (int i = 0; i < getEntryCount(); i++) {
      if (getEntryForIndex(i) == e) return true;
    }

    return false;
  }

  void copy(BaseDataSet baseDataSet) {
    baseDataSet.mAxisDependency = mAxisDependency;
    baseDataSet.mColors = mColors;
    baseDataSet.mDrawIcons = mDrawIcons;
    baseDataSet.mDrawValues = mDrawValues;
    baseDataSet.mForm = mForm;
    baseDataSet.mFormLineDashEffect = mFormLineDashEffect;
    baseDataSet.mFormLineWidth = mFormLineWidth;
    baseDataSet.mFormSize = mFormSize;
    baseDataSet.mGradientColor = mGradientColor;
    baseDataSet.mGradientColors = mGradientColors;
    baseDataSet.mHighlightEnabled = mHighlightEnabled;
    baseDataSet.mIconsOffset = mIconsOffset;
    baseDataSet.mValueColors = mValueColors;
    baseDataSet.mValueFormatter = mValueFormatter;
    baseDataSet.mValueColors = mValueColors;
    baseDataSet.mValueTextSize = mValueTextSize;
    baseDataSet.mVisible = mVisible;
  }
}

abstract class DataSet<T extends Entry> extends BaseDataSet<T> {
  /**
   * the entries that this DataSet represents / holds together
   */
  List<T> mValues = null;

  /**
   * maximum y-value in the value array
   */
  double mYMax = -double.maxFinite;

  /**
   * minimum y-value in the value array
   */
  double mYMin = double.maxFinite;

  /**
   * maximum x-value in the value array
   */
  double mXMax = -double.maxFinite;

  /**
   * minimum x-value in the value array
   */
  double mXMin = double.maxFinite;

  /**
   * Creates a  DataSet object with the given values (entries) it represents. Also, a
   * label that describes the DataSet can be specified. The label can also be
   * used to retrieve the DataSet from a ChartData object.
   *
   * @param values
   * @param label
   */
  DataSet(List<T> values, String label) : super.withLabel(label) {
    this.mValues = values;

    if (mValues == null) mValues = List<T>();

    calcMinMax();
  }

  @override
  void calcMinMax() {
    if (mValues == null || mValues.isEmpty) return;

    mYMax = -double.maxFinite;
    mYMin = double.maxFinite;
    mXMax = -double.maxFinite;
    mXMin = double.maxFinite;

    for (T e in mValues) {
      calcMinMax1(e);
    }
  }

  @override
  void calcMinMaxY(double fromX, double toX) {
    if (mValues == null || mValues.isEmpty) return;

    mYMax = -double.maxFinite;
    mYMin = double.maxFinite;

    int indexFrom = getEntryIndex1(fromX, double.nan, Rounding.DOWN);
    int indexTo = getEntryIndex1(toX, double.nan, Rounding.UP);

    for (int i = indexFrom; i <= indexTo; i++) {
      // only recalculate y
      calcMinMaxY1(mValues[i]);
    }
  }

  /**
   * Updates the min and max x and y value of this DataSet based on the given Entry.
   *
   * @param e
   */
  void calcMinMax1(T e) {
    if (e == null) return;

    calcMinMaxX1(e);

    calcMinMaxY1(e);
  }

  void calcMinMaxX1(T e) {
    if (e.x < mXMin) mXMin = e.x;

    if (e.x > mXMax) mXMax = e.x;
  }

  void calcMinMaxY1(T e) {
    if (e.y < mYMin) mYMin = e.y;

    if (e.y > mYMax) mYMax = e.y;
  }

  @override
  int getEntryCount() {
    return mValues.length;
  }

  /**
   * Returns the array of entries that this DataSet represents.
   *
   * @return
   */
  List<T> getValues() {
    return mValues;
  }

  /**
   * Sets the array of entries that this DataSet represents, and calls notifyDataSetChanged()
   *
   * @return
   */
  void setValues(List<T> values) {
    mValues = values;
    notifyDataSetChanged();
  }

  /**
   * Provides an exact copy of the DataSet this method is used on.
   *
   * @return
   */
  DataSet<T> copy1();

  /**
   *
   * @param dataSet
   */
  void copy2(DataSet dataSet) {
    super.copy(dataSet);
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.write(toSimpleString());
    for (int i = 0; i < mValues.length; i++) {
      buffer.write(mValues[i].toString() + " ");
    }
    return buffer.toString();
  }

  /**
   * Returns a simple string representation of the DataSet with the type and
   * the number of Entries.
   *
   * @return
   */
  String toSimpleString() {
    StringBuffer buffer = StringBuffer();
    buffer.write("DataSet, label: " +
        (getLabel() == null ? "" : getLabel()) +
        ", entries:${mValues.length}\n");
    return buffer.toString();
  }

  @override
  double getYMin() {
    return mYMin;
  }

  @override
  double getYMax() {
    return mYMax;
  }

  @override
  double getXMin() {
    return mXMin;
  }

  @override
  double getXMax() {
    return mXMax;
  }

  @override
  void addEntryOrdered(T e) {
    if (e == null) return;

    if (mValues == null) {
      mValues = List<T>();
    }

    calcMinMax1(e);

    if (mValues.length > 0 && mValues[mValues.length - 1].x > e.x) {
      int closestIndex = getEntryIndex1(e.x, e.y, Rounding.UP);
      mValues.insert(closestIndex, e);
    } else {
      mValues.add(e);
    }
  }

  @override
  void clear() {
    mValues.clear();
    notifyDataSetChanged();
  }

  @override
  bool addEntry(T e) {
    if (e == null) return false;

    List<T> values = getValues();
    if (values == null) {
      values = List<T>();
    }

    calcMinMax1(e);

    // add the entry
    values.add(e);
    return true;
  }

  @override
  bool removeEntry1(T e) {
    if (e == null) return false;

    if (mValues == null) return false;

    // remove the entry
    bool removed = mValues.remove(e);

    if (removed) {
      calcMinMax();
    }

    return removed;
  }

  @override
  int getEntryIndex2(Entry e) {
    return mValues.indexOf(e);
  }

  @override
  T getEntryForXValue1(double xValue, double closestToY, Rounding rounding) {
    int index = getEntryIndex1(xValue, closestToY, rounding);
    if (index > -1) return mValues[index];
    return null;
  }

  @override
  T getEntryForXValue2(double xValue, double closestToY) {
    return getEntryForXValue1(xValue, closestToY, Rounding.CLOSEST);
  }

  @override
  T getEntryForIndex(int index) {
    return mValues[index];
  }

  @override
  int getEntryIndex1(double xValue, double closestToY, Rounding rounding) {
    if (mValues == null || mValues.isEmpty) return -1;

    int low = 0;
    int high = mValues.length - 1;
    int closest = high;

    while (low < high) {
      int m = (low + high) ~/ 2;

      final double d1 = mValues[m].x - xValue,
          d2 = mValues[m + 1].x - xValue,
          ad1 = d1.abs(),
          ad2 = d2.abs();

      if (ad2 < ad1) {
        // [m + 1] is closer to xValue
        // Search in an higher place
        low = m + 1;
      } else if (ad1 < ad2) {
        // [m] is closer to xValue
        // Search in a lower place
        high = m;
      } else {
        // We have multiple sequential x-value with same distance

        if (d1 >= 0.0) {
          // Search in a lower place
          high = m;
        } else if (d1 < 0.0) {
          // Search in an higher place
          low = m + 1;
        }
      }

      closest = high;
    }

    if (closest != -1) {
      double closestXValue = mValues[closest].x;
      if (rounding == Rounding.UP) {
        // If rounding up, and found x-value is lower than specified x, and we can go upper...
        if (closestXValue < xValue && closest < mValues.length - 1) {
          ++closest;
        }
      } else if (rounding == Rounding.DOWN) {
        // If rounding down, and found x-value is upper than specified x, and we can go lower...
        if (closestXValue > xValue && closest > 0) {
          --closest;
        }
      }

      // Search by closest to y-value
      if (!(closestToY.isNaN)) {
        while (closest > 0 && mValues[closest - 1].x == closestXValue)
          closest -= 1;

        double closestYValue = mValues[closest].y;
        int closestYIndex = closest;

        while (true) {
          closest += 1;
          if (closest >= mValues.length) break;

          final Entry value = mValues[closest];

          if (value.x != closestXValue) break;

          if ((value.y - closestToY).abs() <
              (closestYValue - closestToY).abs()) {
            closestYValue = closestToY;
            closestYIndex = closest;
          }
        }

        closest = closestYIndex;
      }
    }

    return closest;
  }

  @override
  List<T> getEntriesForXValue(double xValue) {
    List<T> entries = List<T>();

    int low = 0;
    int high = mValues.length - 1;

    while (low <= high) {
      int m = (high + low) ~/ 2;
      T entry = mValues[m];

      // if we have a match
      if (xValue == entry.x) {
        while (m > 0 && mValues[m - 1].x == xValue) m--;

        high = mValues.length;

        // loop over all "equal" entries
        for (; m < high; m++) {
          entry = mValues[m];
          if (entry.x == xValue) {
            entries.add(entry);
          } else {
            break;
          }
        }

        break;
      } else {
        if (xValue > entry.x)
          low = m + 1;
        else
          high = m - 1;
      }
    }

    return entries;
  }
}

class ChartData<T extends IDataSet<Entry>> {
  /**
   * maximum y-value in the value array across all axes
   */
  double mYMax = -double.infinity;

  /**
   * the minimum y-value in the value array across all axes
   */
  double mYMin = double.infinity;

  /**
   * maximum x-value in the value array
   */
  double mXMax = -double.infinity;

  /**
   * minimum x-value in the value array
   */
  double mXMin = double.infinity;

  double mLeftAxisMax = -double.infinity;

  double mLeftAxisMin = double.infinity;

  double mRightAxisMax = -double.infinity;

  double mRightAxisMin = double.infinity;

  /**
   * array that holds all DataSets the ChartData object represents
   */
  List<T> mDataSets;

  /**
   * Default constructor.
   */
  ChartData() {
    mDataSets = List<T>();
  }

  /**
   * Constructor taking single or multiple DataSet objects.
   *
   * @param dataSets
   */
  ChartData.fromList(List<T> dataSets) {
    mDataSets = dataSets;
    notifyDataChanged();
  }

  /**
   * Call this method to let the ChartData know that the underlying data has
   * changed. Calling this performs all necessary recalculations needed when
   * the contained data has changed.
   */
  void notifyDataChanged() {
    calcMinMax1();
  }

  /**
   * Calc minimum and maximum y-values over all DataSets.
   * Tell DataSets to recalculate their min and max y-values, this is only needed for autoScaleMinMax.
   *
   * @param fromX the x-value to start the calculation from
   * @param toX   the x-value to which the calculation should be performed
   */
  void calcMinMaxY(double fromX, double toX) {
    for (T set in mDataSets) {
      set.calcMinMaxY(fromX, toX);
    }

    // apply the  data
    calcMinMax1();
  }

  /**
   * Calc minimum and maximum values (both x and y) over all DataSets.
   */
  void calcMinMax1() {
    if (mDataSets == null) return;

    mYMax = -double.infinity;
    mYMin = double.infinity;
    mXMax = -double.infinity;
    mXMin = double.infinity;

    for (T set in mDataSets) {
      calcMinMax3(set);
    }

    mLeftAxisMax = -double.infinity;
    mLeftAxisMin = double.infinity;
    mRightAxisMax = -double.infinity;
    mRightAxisMin = double.infinity;

    // left axis
    T firstLeft = getFirstLeft(mDataSets);

    if (firstLeft != null) {
      mLeftAxisMax = firstLeft.getYMax();
      mLeftAxisMin = firstLeft.getYMin();

      for (T dataSet in mDataSets) {
        if (dataSet.getAxisDependency() == AxisDependency.LEFT) {
          if (dataSet.getYMin() < mLeftAxisMin)
            mLeftAxisMin = dataSet.getYMin();

          if (dataSet.getYMax() > mLeftAxisMax)
            mLeftAxisMax = dataSet.getYMax();
        }
      }
    }

    // right axis
    T firstRight = getFirstRight(mDataSets);

    if (firstRight != null) {
      mRightAxisMax = firstRight.getYMax();
      mRightAxisMin = firstRight.getYMin();

      for (T dataSet in mDataSets) {
        if (dataSet.getAxisDependency() == AxisDependency.RIGHT) {
          if (dataSet.getYMin() < mRightAxisMin)
            mRightAxisMin = dataSet.getYMin();

          if (dataSet.getYMax() > mRightAxisMax)
            mRightAxisMax = dataSet.getYMax();
        }
      }
    }
  }

  /** ONLY GETTERS AND SETTERS BELOW THIS */

  /**
   * returns the number of LineDataSets this object contains
   *
   * @return
   */
  int getDataSetCount() {
    if (mDataSets == null) return 0;
    return mDataSets.length;
  }

  /**
   * Returns the smallest y-value the data object contains.
   *
   * @return
   */
  double getYMin1() {
    return mYMin;
  }

  /**
   * Returns the minimum y-value for the specified axis.
   *
   * @param axis
   * @return
   */
  double getYMin2(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      if (mLeftAxisMin.isInfinite) {
        return mRightAxisMin;
      } else
        return mLeftAxisMin;
    } else {
      if (mRightAxisMin.isInfinite) {
        return mLeftAxisMin;
      } else
        return mRightAxisMin;
    }
  }

  /**
   * Returns the greatest y-value the data object contains.
   *
   * @return
   */
  double getYMax1() {
    return mYMax;
  }

  /**
   * Returns the maximum y-value for the specified axis.
   *
   * @param axis
   * @return
   */
  double getYMax2(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      if (mLeftAxisMax == -double.infinity) {
        return mRightAxisMax;
      } else
        return mLeftAxisMax;
    } else {
      if (mRightAxisMax == -double.infinity) {
        return mLeftAxisMax;
      } else
        return mRightAxisMax;
    }
  }

  /**
   * Returns the minimum x-value this data object contains.
   *
   * @return
   */
  double getXMin() {
    return mXMin;
  }

  double getXMax() {
    return mXMax;
  }

  /**
   * Returns all DataSet objects this ChartData object holds.
   *
   * @return
   */
  List<T> getDataSets() {
    return mDataSets;
  }

  /**
   * Retrieve the index of a DataSet with a specific label from the ChartData.
   * Search can be case sensitive or not. IMPORTANT: This method does
   * calculations at runtime, do not over-use in performance critical
   * situations.
   *
   * @param dataSets   the DataSet array to search
   * @param label
   * @param ignorecase if true, the search is not case-sensitive
   * @return
   */
  int getDataSetIndexByLabel(List<T> dataSets, String label, bool ignorecase) {
    if (ignorecase) {
      for (int i = 0; i < dataSets.length; i++)
        if (DartAdapterUtils.equalsIgnoreCase(label, dataSets[i].getLabel()))
          return i;
    } else {
      for (int i = 0; i < dataSets.length; i++)
        if (label == dataSets[i].getLabel()) return i;
    }

    return -1;
  }

  /**
   * Returns the labels of all DataSets as a string array.
   *
   * @return
   */
  List<String> getDataSetLabels() {
    List<String> types = List(mDataSets.length);

    for (int i = 0; i < mDataSets.length; i++) {
      types[i] = mDataSets[i].getLabel();
    }

    return types;
  }

  /**
   * Get the Entry for a corresponding highlight object
   *
   * @param highlight
   * @return the entry that is highlighted
   */
  Entry getEntryForHighlight(Highlight highlight) {
    if (highlight.getDataSetIndex() >= mDataSets.length)
      return null;
    else {
      return mDataSets[highlight.getDataSetIndex()]
          .getEntryForXValue2(highlight.getX(), highlight.getY());
    }
  }

  /**
   * Returns the DataSet object with the given label. Search can be case
   * sensitive or not. IMPORTANT: This method does calculations at runtime.
   * Use with care in performance critical situations.
   *
   * @param label
   * @param ignorecase
   * @return
   */
  T getDataSetByLabel(String label, bool ignorecase) {
    int index = getDataSetIndexByLabel(mDataSets, label, ignorecase);

    if (index < 0 || index >= mDataSets.length)
      return null;
    else
      return mDataSets[index];
  }

  T getDataSetByIndex(int index) {
    if (mDataSets == null || index < 0 || index >= mDataSets.length)
      return null;

    return mDataSets[index];
  }

  /**
   * Adds a DataSet dynamically.
   *
   * @param d
   */
  void addDataSet(T d) {
    if (d == null) return;

    calcMinMax3(d);

    mDataSets.add(d);
  }

  /**
   * Removes the given DataSet from this data object. Also recalculates all
   * minimum and maximum values. Returns true if a DataSet was removed, false
   * if no DataSet could be removed.
   *
   * @param d
   */
  bool removeDataSet1(T d) {
    if (d == null) return false;

    bool removed = mDataSets.remove(d);

    // if a DataSet was removed
    if (removed) {
      calcMinMax1();
    }

    return removed;
  }

  /**
   * Removes the DataSet at the given index in the DataSet array from the data
   * object. Also recalculates all minimum and maximum values. Returns true if
   * a DataSet was removed, false if no DataSet could be removed.
   *
   * @param index
   */
  bool removeDataSet2(int index) {
    if (index >= mDataSets.length || index < 0) return false;

    T set = mDataSets[index];
    return removeDataSet1(set);
  }

  /**
   * Adds an Entry to the DataSet at the specified index.
   * Entries are added to the end of the list.
   *
   * @param e
   * @param dataSetIndex
   */
  void addEntry(Entry e, int dataSetIndex) {
    if (mDataSets.length > dataSetIndex && dataSetIndex >= 0) {
      IDataSet set = mDataSets[dataSetIndex];
      // add the entry to the dataset
      if (!set.addEntry(e)) return;

      calcMinMax2(e, set.getAxisDependency());
    } else {
//      Log.e("addEntry", "Cannot add Entry because dataSetIndex too high or too low.");
    }
  }

  /**
   * Adjusts the current minimum and maximum values based on the provided Entry object.
   *
   * @param e
   * @param axis
   */
  void calcMinMax2(Entry e, AxisDependency axis) {
    if (mYMax < e.y) mYMax = e.y;
    if (mYMin > e.y) mYMin = e.y;

    if (mXMax < e.x) mXMax = e.x;
    if (mXMin > e.x) mXMin = e.x;

    if (axis == AxisDependency.LEFT) {
      if (mLeftAxisMax < e.y) mLeftAxisMax = e.y;
      if (mLeftAxisMin > e.y) mLeftAxisMin = e.y;
    } else {
      if (mRightAxisMax < e.y) mRightAxisMax = e.y;
      if (mRightAxisMin > e.y) mRightAxisMin = e.y;
    }
  }

  /**
   * Adjusts the minimum and maximum values based on the given DataSet.
   *
   * @param d
   */
  void calcMinMax3(T d) {
    if (mYMax < d.getYMax()) mYMax = d.getYMax();
    if (mYMin > d.getYMin()) mYMin = d.getYMin();

    if (mXMax < d.getXMax()) mXMax = d.getXMax();
    if (mXMin > d.getXMin()) mXMin = d.getXMin();

    if (d.getAxisDependency() == AxisDependency.LEFT) {
      if (mLeftAxisMax < d.getYMax()) mLeftAxisMax = d.getYMax();
      if (mLeftAxisMin > d.getYMin()) mLeftAxisMin = d.getYMin();
    } else {
      if (mRightAxisMax < d.getYMax()) mRightAxisMax = d.getYMax();
      if (mRightAxisMin > d.getYMin()) mRightAxisMin = d.getYMin();
    }
  }

  /**
   * Removes the given Entry object from the DataSet at the specified index.
   *
   * @param e
   * @param dataSetIndex
   */
  bool removeEntry1(Entry e, int dataSetIndex) {
    // entry null, outofbounds
    if (e == null || dataSetIndex >= mDataSets.length) return false;

    IDataSet set = mDataSets[dataSetIndex];

    if (set != null) {
      // remove the entry from the dataset
      bool removed = set.removeEntry1(e);

      if (removed) {
        calcMinMax1();
      }

      return removed;
    } else
      return false;
  }

  /**
   * Removes the Entry object closest to the given DataSet at the
   * specified index. Returns true if an Entry was removed, false if no Entry
   * was found that meets the specified requirements.
   *
   * @param xValue
   * @param dataSetIndex
   * @return
   */
  bool removeEntry2(double xValue, int dataSetIndex) {
    if (dataSetIndex >= mDataSets.length) return false;

    IDataSet dataSet = mDataSets[dataSetIndex];
    Entry e = dataSet.getEntryForXValue2(xValue, double.nan);

    if (e == null) return false;

    return removeEntry1(e, dataSetIndex);
  }

  /**
   * Returns the DataSet that contains the provided Entry, or null, if no
   * DataSet contains this Entry.
   *
   * @param e
   * @return
   */
  T getDataSetForEntry(Entry e) {
    if (e == null) return null;

    for (int i = 0; i < mDataSets.length; i++) {
      T set = mDataSets[i];

      for (int j = 0; j < set.getEntryCount(); j++) {
        if (e == set.getEntryForXValue2(e.x, e.y)) return set;
      }
    }

    return null;
  }

  /**
   * Returns all colors used across all DataSet objects this object
   * represents.
   *
   * @return
   */
  List<ui.Color> getColors() {
    if (mDataSets == null) return null;

    int clrcnt = 0;

    for (int i = 0; i < mDataSets.length; i++) {
      clrcnt += mDataSets[i].getColors().length;
    }

    List<ui.Color> colors = List(clrcnt);
    int cnt = 0;

    for (int i = 0; i < mDataSets.length; i++) {
      List<ui.Color> clrs = mDataSets[i].getColors();

      for (ui.Color clr in clrs) {
        colors[cnt] = clr;
        cnt++;
      }
    }

    return colors;
  }

  /**
   * Returns the index of the provided DataSet in the DataSet array of this data object, or -1 if it does not exist.
   *
   * @param dataSet
   * @return
   */
  int getIndexOfDataSet(T dataSet) {
    return mDataSets.indexOf(dataSet);
  }

  /**
   * Returns the first DataSet from the datasets-array that has it's dependency on the left axis.
   * Returns null if no DataSet with left dependency could be found.
   *
   * @return
   */
  T getFirstLeft(List<T> sets) {
    for (T dataSet in sets) {
      if (dataSet.getAxisDependency() == AxisDependency.LEFT) return dataSet;
    }
    return null;
  }

  /**
   * Returns the first DataSet from the datasets-array that has it's dependency on the right axis.
   * Returns null if no DataSet with right dependency could be found.
   *
   * @return
   */
  T getFirstRight(List<T> sets) {
    for (T dataSet in sets) {
      if (dataSet.getAxisDependency() == AxisDependency.RIGHT) return dataSet;
    }
    return null;
  }

  /**
   * Sets a custom IValueFormatter for all DataSets this data object contains.
   *
   * @param f
   */
  void setValueFormatter(ValueFormatter f) {
    if (f == null)
      return;
    else {
      for (IDataSet set in mDataSets) {
        set.setValueFormatter(f);
      }
    }
  }

  /**
   * Sets the color of the value-text (color in which the value-labels are
   * drawn) for all DataSets this data object contains.
   *
   * @param color
   */
  void setValueTextColor(ui.Color color) {
    for (IDataSet set in mDataSets) {
      set.setValueTextColor(color);
    }
  }

  /**
   * Sets the same list of value-colors for all DataSets this
   * data object contains.
   *
   * @param colors
   */
  void setValueTextColors(List<ui.Color> colors) {
    for (IDataSet set in mDataSets) {
      set.setValueTextColors(colors);
    }
  }

  /**
   * Sets the Typeface for all value-labels for all DataSets this data object
   * contains.
   *
   * @param tf
   */
  void setValueTypeface(TextStyle tf) {
    for (IDataSet set in mDataSets) {
      set.setValueTypeface(tf);
    }
  }

  /**
   * Sets the size (in dp) of the value-text for all DataSets this data object
   * contains.
   *
   * @param size
   */
  void setValueTextSize(double size) {
    for (IDataSet set in mDataSets) {
      set.setValueTextSize(size);
    }
  }

  /**
   * Enables / disables drawing values (value-text) for all DataSets this data
   * object contains.
   *
   * @param enabled
   */
  void setDrawValues(bool enabled) {
    for (IDataSet set in mDataSets) {
      set.setDrawValues(enabled);
    }
  }

  /**
   * Enables / disables highlighting values for all DataSets this data object
   * contains. If set to true, this means that values can
   * be highlighted programmatically or by touch gesture.
   */
  void setHighlightEnabled(bool enabled) {
    for (IDataSet set in mDataSets) {
      set.setHighlightEnabled(enabled);
    }
  }

  /**
   * Returns true if highlighting of all underlying values is enabled, false
   * if not.
   *
   * @return
   */
  bool isHighlightEnabled() {
    for (IDataSet set in mDataSets) {
      if (!set.isHighlightEnabled()) return false;
    }
    return true;
  }

  /**
   * Clears this data object from all DataSets and removes all Entries. Don't
   * forget to invalidate the chart after this.
   */
  void clearValues() {
    if (mDataSets != null) {
      mDataSets.clear();
    }
    notifyDataChanged();
  }

  /**
   * Checks if this data object contains the specified DataSet. Returns true
   * if so, false if not.
   *
   * @param dataSet
   * @return
   */
  bool contains(T dataSet) {
    for (T set in mDataSets) {
      if (set == dataSet) return true;
    }
    return false;
  }

  /**
   * Returns the total entry count across all DataSet objects this data object contains.
   *
   * @return
   */
  int getEntryCount() {
    int count = 0;
    for (T set in mDataSets) {
      count += set.getEntryCount();
    }
    return count;
  }

  /**
   * Returns the DataSet object with the maximum number of entries or null if there are no DataSets.
   *
   * @return
   */
  T getMaxEntryCountSet() {
    if (mDataSets == null || mDataSets.isEmpty) return null;
    T max = mDataSets[0];
    for (T set in mDataSets) {
      if (set.getEntryCount() > max.getEntryCount()) max = set;
    }
    return max;
  }
}

class BarLineScatterCandleBubbleData<
    T extends IBarLineScatterCandleBubbleDataSet<Entry>> extends ChartData<T> {
  BarLineScatterCandleBubbleData() : super();

  BarLineScatterCandleBubbleData.fromList(List<T> sets) : super.fromList(sets);
}

class LineData extends BarLineScatterCandleBubbleData<ILineDataSet> {
  LineData() : super();

  LineData.fromList(List<ILineDataSet> sets) : super.fromList(sets);
}

class BarData extends BarLineScatterCandleBubbleData<IBarDataSet> {
  /**
   * the width of the bars on the x-axis, in values (not pixels)
   */
  double mBarWidth = 0.85;

  BarData(List<IBarDataSet> dataSets) : super.fromList(dataSets);

  /**
   * Sets the width each bar should have on the x-axis (in values, not pixels).
   * Default 0.85f
   *
   * @param mBarWidth
   */
  void setBarWidth(double mBarWidth) {
    this.mBarWidth = mBarWidth;
  }

  double getBarWidth() {
    return mBarWidth;
  }

  /**
   * Groups all BarDataSet objects this data object holds together by modifying the x-value of their entries.
   * Previously set x-values of entries will be overwritten. Leaves space between bars and groups as specified
   * by the parameters.
   * Do not forget to call notifyDataSetChanged() on your BarChart object after calling this method.
   *
   * @param fromX      the starting point on the x-axis where the grouping should begin
   * @param groupSpace the space between groups of bars in values (not pixels) e.g. 0.8f for bar width 1f
   * @param barSpace   the space between individual bars in values (not pixels) e.g. 0.1f for bar width 1f
   */
  void groupBars(double fromX, double groupSpace, double barSpace) {
    int setCount = mDataSets.length;
    if (setCount <= 1) {
      throw Exception(
          "BarData needs to hold at least 2 BarDataSets to allow grouping.");
    }

    IBarDataSet max = getMaxEntryCountSet();
    int maxEntryCount = max.getEntryCount();

    double groupSpaceWidthHalf = groupSpace / 2.0;
    double barSpaceHalf = barSpace / 2.0;
    double barWidthHalf = mBarWidth / 2.0;

    double interval = getGroupWidth(groupSpace, barSpace);

    for (int i = 0; i < maxEntryCount; i++) {
      double start = fromX;
      fromX += groupSpaceWidthHalf;

      for (IBarDataSet set in mDataSets) {
        fromX += barSpaceHalf;
        fromX += barWidthHalf;

        if (i < set.getEntryCount()) {
          BarEntry entry = set.getEntryForIndex(i);

          if (entry != null) {
            entry.x = fromX;
          }
        }

        fromX += barWidthHalf;
        fromX += barSpaceHalf;
      }

      fromX += groupSpaceWidthHalf;
      double end = fromX;
      double innerInterval = end - start;
      double diff = interval - innerInterval;

      // correct rounding errors
      if (diff > 0 || diff < 0) {
        fromX += diff;
      }
    }

    // maybe todo
    notifyDataChanged();
  }

  /**
   * In case of grouped bars, this method returns the space an individual group of bar needs on the x-axis.
   *
   * @param groupSpace
   * @param barSpace
   * @return
   */
  double getGroupWidth(double groupSpace, double barSpace) {
    return mDataSets.length * (mBarWidth + barSpace) + groupSpace;
  }
}

abstract class BarLineScatterCandleBubbleDataSet<T extends Entry>
    extends DataSet<T> implements IBarLineScatterCandleBubbleDataSet<T> {
  ui.Color mHighLightColor = ui.Color.fromARGB(255, 255, 187, 115);

  BarLineScatterCandleBubbleDataSet(List<T> yVals, String label)
      : super(yVals, label);

  /**
   * Sets the color that is used for drawing the highlight indicators. Dont
   * forget to resolve the color using getResources().getColor(...) or
   * Color.rgb(...).
   *
   * @param color
   */
  void setHighLightColor(ui.Color color) {
    mHighLightColor = color;
  }

  @override
  ui.Color getHighLightColor() {
    return mHighLightColor;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BarLineScatterCandleBubbleDataSet) {
      var barLineScatterCandleBubbleDataSet =
          baseDataSet as BarLineScatterCandleBubbleDataSet;
      barLineScatterCandleBubbleDataSet.mHighLightColor = mHighLightColor;
    }
  }
}

class BarDataSet extends BarLineScatterCandleBubbleDataSet<BarEntry>
    implements IBarDataSet {
  /**
   * the maximum number of bars that are stacked upon each other, this value
   * is calculated from the Entries that are added to the DataSet
   */
  int mStackSize = 1;

  /**
   * the color used for drawing the bar shadows
   */
  Color mBarShadowColor = Color.fromARGB(255, 215, 215, 215);

  double mBarBorderWidth = 0.0;

  Color mBarBorderColor = ColorUtils.BLACK;

  /**
   * the alpha value used to draw the highlight indicator bar
   */
  int mHighLightAlpha = 120;

  /**
   * the overall entry count, including counting each stack-value individually
   */
  int mEntryCountStacks = 0;

  /**
   * array of labels used to describe the different values of the stacked bars
   */
  List<String> mStackLabels = List()..add("Stack");

  BarDataSet(List<BarEntry> yVals, String label) : super(yVals, label) {
    mHighLightColor = Color.fromARGB(255, 0, 0, 0);

    calcStackSize(yVals);
    calcEntryCountIncludingStacks(yVals);
  }

  @override
  DataSet<BarEntry> copy1() {
    List<BarEntry> entries = List();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(mValues[i].copy());
    }
    BarDataSet copied = BarDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BarDataSet) {
      var barDataSet = baseDataSet as BarDataSet;
      barDataSet.mStackSize = mStackSize;
      barDataSet.mBarShadowColor = mBarShadowColor;
      barDataSet.mBarBorderWidth = mBarBorderWidth;
      barDataSet.mStackLabels = mStackLabels;
      barDataSet.mHighLightAlpha = mHighLightAlpha;
    }
  }

  /**
   * Calculates the total number of entries this DataSet represents, including
   * stacks. All values belonging to a stack are calculated separately.
   */
  void calcEntryCountIncludingStacks(List<BarEntry> yVals) {
    mEntryCountStacks = 0;

    for (int i = 0; i < yVals.length; i++) {
      List<double> vals = yVals[i].getYVals();

      if (vals == null)
        mEntryCountStacks++;
      else
        mEntryCountStacks += vals.length;
    }
  }

  /**
   * calculates the maximum stacksize that occurs in the Entries array of this
   * DataSet
   */
  void calcStackSize(List<BarEntry> yVals) {
    for (int i = 0; i < yVals.length; i++) {
      List<double> vals = yVals[i].getYVals();

      if (vals != null && vals.length > mStackSize) mStackSize = vals.length;
    }
  }

  @override
  void calcMinMax1(BarEntry e) {
    if (e != null && !e.y.isNaN) {
      if (e.getYVals() == null) {
        if (e.y < mYMin) mYMin = e.y;

        if (e.y > mYMax) mYMax = e.y;
      } else {
        if (-e.getNegativeSum() < mYMin) mYMin = -e.getNegativeSum();

        if (e.getPositiveSum() > mYMax) mYMax = e.getPositiveSum();
      }

      calcMinMaxX1(e);
    }
  }

  @override
  int getStackSize() {
    return mStackSize;
  }

  @override
  bool isStacked() {
    return mStackSize > 1 ? true : false;
  }

  /**
   * returns the overall entry count, including counting each stack-value
   * individually
   *
   * @return
   */
  int getEntryCountStacks() {
    return mEntryCountStacks;
  }

  /**
   * Sets the color used for drawing the bar-shadows. The bar shadows is a
   * surface behind the bar that indicates the maximum value. Don't for get to
   * use getResources().getColor(...) to set this. Or Color.rgb(...).
   *
   * @param color
   */
  void setBarShadowColor(Color color) {
    mBarShadowColor = color;
  }

  @override
  Color getBarShadowColor() {
    return mBarShadowColor;
  }

  /**
   * Sets the width used for drawing borders around the bars.
   * If borderWidth == 0, no border will be drawn.
   *
   * @return
   */
  void setBarBorderWidth(double width) {
    mBarBorderWidth = width;
  }

  /**
   * Returns the width used for drawing borders around the bars.
   * If borderWidth == 0, no border will be drawn.
   *
   * @return
   */
  @override
  double getBarBorderWidth() {
    return mBarBorderWidth;
  }

  /**
   * Sets the color drawing borders around the bars.
   *
   * @return
   */
  void setBarBorderColor(Color color) {
    mBarBorderColor = color;
  }

  /**
   * Returns the color drawing borders around the bars.
   *
   * @return
   */
  @override
  Color getBarBorderColor() {
    return mBarBorderColor;
  }

  /**
   * Set the alpha value (transparency) that is used for drawing the highlight
   * indicator bar. min = 0 (fully transparent), max = 255 (fully opaque)
   *
   * @param alpha
   */
  void setHighLightAlpha(int alpha) {
    mHighLightAlpha = alpha;
  }

  @override
  int getHighLightAlpha() {
    return mHighLightAlpha;
  }

  /**
   * Sets labels for different values of bar-stacks, in case there are one.
   *
   * @param labels
   */
  void setStackLabels(List<String> labels) {
    mStackLabels = labels;
  }

  @override
  List<String> getStackLabels() {
    return mStackLabels;
  }
}

class PieDataSet extends DataSet<PieEntry> implements IPieDataSet {
  /**
   * the space in pixels between the chart-slices, default 0f
   */
  double mSliceSpace = 0;
  bool mAutomaticallyDisableSliceSpacing = false;

  /**
   * indicates the selection distance of a pie slice
   */
  double mShift = 18;

  ValuePosition mXValuePosition = ValuePosition.INSIDE_SLICE;
  ValuePosition mYValuePosition = ValuePosition.INSIDE_SLICE;
  bool mUsingSliceColorAsValueLineColor = false;
  Color mValueLineColor = Color(0xff000000);
  double mValueLineWidth = 1.0;
  double mValueLinePart1OffsetPercentage = 75.0;
  double mValueLinePart1Length = 0.3;
  double mValueLinePart2Length = 0.4;
  bool mValueLineVariableLength = true;

  PieDataSet(List<PieEntry> yVals, String label) : super(yVals, label);

  @override
  DataSet<PieEntry> copy1() {
    List<PieEntry> entries = List();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(mValues[i].copy());
    }
    PieDataSet copied = PieDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
  }

  @override
  void calcMinMax1(PieEntry e) {
    if (e == null) return;
    calcMinMaxY1(e);
  }

  /**
   * Sets the space that is left out between the piechart-slices in dp.
   * Default: 0 --> no space, maximum 20f
   *
   * @param spaceDp
   */
  void setSliceSpace(double spaceDp) {
    if (spaceDp > 20) spaceDp = 20;
    if (spaceDp < 0) spaceDp = 0;

    mSliceSpace = Utils.convertDpToPixel(spaceDp);
  }

  @override
  double getSliceSpace() {
    return mSliceSpace;
  }

  /**
   * When enabled, slice spacing will be 0.0 when the smallest value is going to be
   * smaller than the slice spacing itself.
   *
   * @param autoDisable
   */
  void setAutomaticallyDisableSliceSpacing(bool autoDisable) {
    mAutomaticallyDisableSliceSpacing = autoDisable;
  }

  /**
   * When enabled, slice spacing will be 0.0 when the smallest value is going to be
   * smaller than the slice spacing itself.
   *
   * @return
   */
  @override
  bool isAutomaticallyDisableSliceSpacingEnabled() {
    return mAutomaticallyDisableSliceSpacing;
  }

  /**
   * sets the distance the highlighted piechart-slice of this DataSet is
   * "shifted" away from the center of the chart, default 12f
   *
   * @param shift
   */
  void setSelectionShift(double shift) {
    mShift = Utils.convertDpToPixel(shift);
  }

  @override
  double getSelectionShift() {
    return mShift;
  }

  @override
  ValuePosition getXValuePosition() {
    return mXValuePosition;
  }

  void setXValuePosition(ValuePosition xValuePosition) {
    this.mXValuePosition = xValuePosition;
  }

  @override
  ValuePosition getYValuePosition() {
    return mYValuePosition;
  }

  void setYValuePosition(ValuePosition yValuePosition) {
    this.mYValuePosition = yValuePosition;
  }

  /**
   * When valuePosition is OutsideSlice, use slice colors as line color if true
   */
  @override
  bool isUsingSliceColorAsValueLineColor() {
    return mUsingSliceColorAsValueLineColor;
  }

  void setUsingSliceColorAsValueLineColor(
      bool usingSliceColorAsValueLineColor) {
    this.mUsingSliceColorAsValueLineColor = usingSliceColorAsValueLineColor;
  }

  /**
   * When valuePosition is OutsideSlice, indicates line color
   */
  @override
  Color getValueLineColor() {
    return mValueLineColor;
  }

  void setValueLineColor(Color valueLineColor) {
    this.mValueLineColor = valueLineColor;
  }

  /**
   * When valuePosition is OutsideSlice, indicates line width
   */
  @override
  double getValueLineWidth() {
    return mValueLineWidth;
  }

  void setValueLineWidth(double valueLineWidth) {
    this.mValueLineWidth = valueLineWidth;
  }

  /**
   * When valuePosition is OutsideSlice, indicates offset as percentage out of the slice size
   */
  @override
  double getValueLinePart1OffsetPercentage() {
    return mValueLinePart1OffsetPercentage;
  }

  void setValueLinePart1OffsetPercentage(
      double valueLinePart1OffsetPercentage) {
    this.mValueLinePart1OffsetPercentage = valueLinePart1OffsetPercentage;
  }

  /**
   * When valuePosition is OutsideSlice, indicates length of first half of the line
   */
  @override
  double getValueLinePart1Length() {
    return mValueLinePart1Length;
  }

  void setValueLinePart1Length(double valueLinePart1Length) {
    this.mValueLinePart1Length = valueLinePart1Length;
  }

  /**
   * When valuePosition is OutsideSlice, indicates length of second half of the line
   */
  @override
  double getValueLinePart2Length() {
    return mValueLinePart2Length;
  }

  void setValueLinePart2Length(double valueLinePart2Length) {
    this.mValueLinePart2Length = valueLinePart2Length;
  }

  /**
   * When valuePosition is OutsideSlice, this allows variable line length
   */
  @override
  bool isValueLineVariableLength() {
    return mValueLineVariableLength;
  }

  void setValueLineVariableLength(bool valueLineVariableLength) {
    this.mValueLineVariableLength = valueLineVariableLength;
  }
}

abstract class LineScatterCandleRadarDataSet<T extends Entry>
    extends BarLineScatterCandleBubbleDataSet<T>
    implements ILineScatterCandleRadarDataSet<T> {
  bool mDrawVerticalHighlightIndicator = true;
  bool mDrawHorizontalHighlightIndicator = true;

  /** the width of the highlight indicator lines */
  double mHighlightLineWidth = 0.5;

  /** the path effect for dashed highlight-lines */
//   DashPathEffect mHighlightDashPathEffect = null;

  LineScatterCandleRadarDataSet(List<T> yVals, String label)
      : super(yVals, label) {
    mHighlightLineWidth = Utils.convertDpToPixel(0.5);
  }

  /**
   * Enables / disables the horizontal highlight-indicator. If disabled, the indicator is not drawn.
   * @param enabled
   */
  void setDrawHorizontalHighlightIndicator(bool enabled) {
    this.mDrawHorizontalHighlightIndicator = enabled;
  }

  /**
   * Enables / disables the vertical highlight-indicator. If disabled, the indicator is not drawn.
   * @param enabled
   */
  void setDrawVerticalHighlightIndicator(bool enabled) {
    this.mDrawVerticalHighlightIndicator = enabled;
  }

  /**
   * Enables / disables both vertical and horizontal highlight-indicators.
   * @param enabled
   */
  void setDrawHighlightIndicators(bool enabled) {
    setDrawVerticalHighlightIndicator(enabled);
    setDrawHorizontalHighlightIndicator(enabled);
  }

  @override
  bool isVerticalHighlightIndicatorEnabled() {
    return mDrawVerticalHighlightIndicator;
  }

  @override
  bool isHorizontalHighlightIndicatorEnabled() {
    return mDrawHorizontalHighlightIndicator;
  }

  /**
   * Sets the width of the highlight line in dp.
   * @param width
   */
  void setHighlightLineWidth(double width) {
    mHighlightLineWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getHighlightLineWidth() {
    return mHighlightLineWidth;
  }

  /**
   * Enables the highlight-line to be drawn in dashed mode, e.g. like this "- - - - - -"
   *
   * @param lineLength the length of the line pieces
   * @param spaceLength the length of space inbetween the line-pieces
   * @param phase offset, in degrees (normally, use 0)
   */
//   void enableDashedHighlightLine(double lineLength, double spaceLength, double phase) {
//    mHighlightDashPathEffect =  DashPathEffect( double[] {
//    lineLength, spaceLength
//    }, phase);
//  }

  /**
   * Disables the highlight-line to be drawn in dashed mode.
   */
//   void disableDashedHighlightLine() {
//    mHighlightDashPathEffect = null;
//  }

  /**
   * Returns true if the dashed-line effect is enabled for highlight lines, false if not.
   * Default: disabled
   *
   * @return
   */
//   bool isDashedHighlightLineEnabled() {
//    return mHighlightDashPathEffect == null ? false : true;
//  }

//  @override
//   DashPathEffect getDashPathEffectHighlight() {
//    return mHighlightDashPathEffect;
//  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is LineScatterCandleRadarDataSet) {
      var lineScatterCandleRadarDataSet =
          baseDataSet as LineScatterCandleRadarDataSet;
      lineScatterCandleRadarDataSet.mDrawHorizontalHighlightIndicator =
          mDrawHorizontalHighlightIndicator;
      lineScatterCandleRadarDataSet.mDrawVerticalHighlightIndicator =
          mDrawVerticalHighlightIndicator;
      lineScatterCandleRadarDataSet.mHighlightLineWidth = mHighlightLineWidth;
//    lineScatterCandleRadarDataSet.mHighlightDashPathEffect = mHighlightDashPathEffect;
    }
  }
}

abstract class LineRadarDataSet<T extends Entry>
    extends LineScatterCandleRadarDataSet<T> implements ILineRadarDataSet<T> {
  /**
   * the color that is used for filling the line surface
   */
  ui.Color mFillColor = ui.Color.fromARGB(255, 140, 234, 255);

  /**
   * the drawable to be used for filling the line surface
   */
//   Drawable mFillDrawable;

  /**
   * transparency used for filling line surface
   */
  int mFillAlpha = 85;

  /**
   * the width of the drawn data lines
   */
  double mLineWidth = 2.5;

  /**
   * if true, the data will also be drawn filled
   */
  bool mDrawFilled = false;

  LineRadarDataSet(List<T> yVals, String label) : super(yVals, label);

  @override
  ui.Color getFillColor() {
    return mFillColor;
  }

  /**
   * Sets the color that is used for filling the area below the line.
   * Resets an eventually set "fillDrawable".
   *
   * @param color
   */
  void setFillColor(ui.Color color) {
    mFillColor = color;
//    mFillDrawable = null;
  }

//  @override
//   Drawable getFillDrawable() {
//    return mFillDrawable;
//  }

  /**
   * Sets the drawable to be used to fill the area below the line.
   *
   * @param drawable
   */
//   void setFillDrawable(Drawable drawable) {
//    this.mFillDrawable = drawable;
//  }

  @override
  int getFillAlpha() {
    return mFillAlpha;
  }

  /**
   * sets the alpha value (transparency) that is used for filling the line
   * surface (0-255), default: 85
   *
   * @param alpha
   */
  void setFillAlpha(int alpha) {
    mFillAlpha = alpha;
  }

  /**
   * set the line width of the chart (min = 0.2f, max = 10f); default 1f NOTE:
   * thinner line == better performance, thicker line == worse performance
   *
   * @param width
   */
  void setLineWidth(double width) {
    if (width < 0.0) width = 0.0;
    if (width > 10.0) width = 10.0;
    mLineWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getLineWidth() {
    return mLineWidth;
  }

  @override
  void setDrawFilled(bool filled) {
    mDrawFilled = filled;
  }

  @override
  bool isDrawFilledEnabled() {
    return mDrawFilled;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);

    if (baseDataSet is LineRadarDataSet) {
      var lineRadarDataSet = baseDataSet as LineRadarDataSet;
      lineRadarDataSet.mDrawFilled = mDrawFilled;
      lineRadarDataSet.mFillAlpha = mFillAlpha;
      lineRadarDataSet.mFillColor = mFillColor;
//      lineRadarDataSet.mFillDrawable = mFillDrawable;
      lineRadarDataSet.mLineWidth = mLineWidth;
    }
  }
}

class LineDataSet extends LineRadarDataSet<Entry> implements ILineDataSet {
  /**
   * Drawing mode for this line dataset
   **/
  Mode mMode = Mode.LINEAR;

  /**
   * List representing all colors that are used for the circles
   */
  List<ui.Color> mCircleColors = null;

  /**
   * the color of the inner circles
   */
  ui.Color mCircleHoleColor = ColorUtils.WHITE;

  /**
   * the radius of the circle-shaped value indicators
   */
  double mCircleRadius = 8;

  /**
   * the hole radius of the circle-shaped value indicators
   */
  double mCircleHoleRadius = 4;

  /**
   * sets the intensity of the cubic lines
   */
  double mCubicIntensity = 0.2;

  /**
   * the path effect of this DataSet that makes dashed lines possible
   */
  DashPathEffect mDashPathEffect = null;

  /**
   * formatter for customizing the position of the fill-line
   */
  IFillFormatter mFillFormatter = DefaultFillFormatter();

  /**
   * if true, drawing circles is enabled
   */
  bool mDrawCircles = true;

  bool mDrawCircleHole = true;

  LineDataSet(List<Entry> yVals, String label) : super(yVals, label) {
    // mCircleRadius = Utils.convertDpToPixel(4f);
    // mLineWidth = Utils.convertDpToPixel(1f);

    if (mCircleColors == null) {
      mCircleColors = List();
    }
    mCircleColors.clear();

    // default colors
    // mColors.add(Color.rgb(192, 255, 140));
    // mColors.add(Color.rgb(255, 247, 140));
    mCircleColors.add(ui.Color.fromARGB(255, 140, 234, 255));
  }

  @override
  DataSet<Entry> copy1() {
    List<Entry> entries = List();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(Entry(
          x: mValues[i].x,
          y: mValues[i].y,
          icon: mValues[i].mIcon,
          data: mValues[i].mData));
    }
    LineDataSet copied = LineDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is LineDataSet) {
      var lineDataSet = baseDataSet as LineDataSet;
      lineDataSet.mCircleColors = mCircleColors;
      lineDataSet.mCircleHoleColor = mCircleHoleColor;
      lineDataSet.mCircleHoleRadius = mCircleHoleRadius;
      lineDataSet.mCircleRadius = mCircleRadius;
      lineDataSet.mCubicIntensity = mCubicIntensity;
      lineDataSet.mDashPathEffect = mDashPathEffect;
      lineDataSet.mDrawCircleHole = mDrawCircleHole;
      lineDataSet.mDrawCircles = mDrawCircleHole;
      lineDataSet.mFillFormatter = mFillFormatter;
      lineDataSet.mMode = mMode;
    }
  }

  /**
   * Returns the drawing mode for this line dataset
   *
   * @return
   */
  @override
  Mode getMode() {
    return mMode;
  }

  /**
   * Returns the drawing mode for this LineDataSet
   *
   * @return
   */
  void setMode(Mode mode) {
    mMode = mode;
  }

  /**
   * Sets the intensity for cubic lines (if enabled). Max = 1f = very cubic,
   * Min = 0.05f = low cubic effect, Default: 0.2f
   *
   * @param intensity
   */
  void setCubicIntensity(double intensity) {
    if (intensity > 1) intensity = 1;
    if (intensity < 0.05) intensity = 0.05;

    mCubicIntensity = intensity;
  }

  @override
  double getCubicIntensity() {
    return mCubicIntensity;
  }

  /**
   * Sets the radius of the drawn circles.
   * Default radius = 4f, Min = 1f
   *
   * @param radius
   */
  void setCircleRadius(double radius) {
    if (radius >= 1) {
      mCircleRadius = Utils.convertDpToPixel(radius);
    }
//    else {
//      Log.e("LineDataSet", "Circle radius cannot be < 1");
//    }
  }

  @override
  double getCircleRadius() {
    return mCircleRadius;
  }

  /**
   * Sets the hole radius of the drawn circles.
   * Default radius = 2f, Min = 0.5f
   *
   * @param holeRadius
   */
  void setCircleHoleRadius(double holeRadius) {
    if (holeRadius >= 0.5) {
      mCircleHoleRadius = Utils.convertDpToPixel(holeRadius);
    }
//    else {
//      Log.e("LineDataSet", "Circle radius cannot be < 0.5");
//    }
  }

  @override
  double getCircleHoleRadius() {
    return mCircleHoleRadius;
  }

  /**
   * sets the size (radius) of the circle shpaed value indicators,
   * default size = 4f
   * <p/>
   * This method is deprecated because of unclarity. Use setCircleRadius instead.
   *
   * @param size
   */
  void setCircleSize(double size) {
    setCircleRadius(size);
  }

  /**
   * This function is deprecated because of unclarity. Use getCircleRadius instead.
   */
  double getCircleSize() {
    return getCircleRadius();
  }

  /**
   * Enables the line to be drawn in dashed mode, e.g. like this
   * "- - - - - -". THIS ONLY WORKS IF HARDWARE-ACCELERATION IS TURNED OFF.
   * Keep in mind that hardware acceleration boosts performance.
   *
   * @param lineLength  the length of the line pieces
   * @param spaceLength the length of space in between the pieces
   * @param phase       offset, in degrees (normally, use 0)
   */
//  void enableDashedLine(double lineLength, double spaceLength, double phase) {
//    mDashPathEffect =  DashPathEffect( double[]{
//    lineLength, spaceLength
//    }, phase);
//  }

  /**
   * Disables the line to be drawn in dashed mode.
   */
  void disableDashedLine() {
    mDashPathEffect = null;
  }

  @override
  bool isDashedLineEnabled() {
    return mDashPathEffect == null ? false : true;
  }

//  @override
//   DashPathEffect getDashPathEffect() {
//    return mDashPathEffect;
//  }

  /**
   * set this to true to enable the drawing of circle indicators for this
   * DataSet, default true
   *
   * @param enabled
   */
  void setDrawCircles(bool enabled) {
    this.mDrawCircles = enabled;
  }

  @override
  bool isDrawCirclesEnabled() {
    return mDrawCircles;
  }

  @override
  bool isDrawCubicEnabled() {
    return mMode == Mode.CUBIC_BEZIER;
  }

  @override
  bool isDrawSteppedEnabled() {
    return mMode == Mode.STEPPED;
  }

  /** ALL CODE BELOW RELATED TO CIRCLE-COLORS */

  /**
   * returns all colors specified for the circles
   *
   * @return
   */
  List<ui.Color> getCircleColors() {
    return mCircleColors;
  }

  @override
  ui.Color getCircleColor(int index) {
    return mCircleColors[index];
  }

  @override
  int getCircleColorCount() {
    return mCircleColors.length;
  }

  /**
   * Sets the colors that should be used for the circles of this DataSet.
   * Colors are reused as soon as the number of Entries the DataSet represents
   * is higher than the size of the colors array. Make sure that the colors
   * are already prepared (by calling getResources().getColor(...)) before
   * adding them to the DataSet.
   *
   * @param colors
   */
  void setCircleColors(List<ui.Color> colors) {
    mCircleColors = colors;
  }

  /**
   * Sets the one and ONLY color that should be used for this DataSet.
   * Internally, this recreates the colors array and adds the specified color.
   *
   * @param color
   */
  void setCircleColor(ui.Color color) {
    resetCircleColors();
    mCircleColors.add(color);
  }

  /**
   * resets the circle-colors array and creates a  one
   */
  void resetCircleColors() {
    if (mCircleColors == null) {
      mCircleColors = List();
    }
    mCircleColors.clear();
  }

  /**
   * Sets the color of the inner circle of the line-circles.
   *
   * @param color
   */
  void setCircleHoleColor(ui.Color color) {
    mCircleHoleColor = color;
  }

  @override
  ui.Color getCircleHoleColor() {
    return mCircleHoleColor;
  }

  /**
   * Set this to true to allow drawing a hole in each data circle.
   *
   * @param enabled
   */
  void setDrawCircleHole(bool enabled) {
    mDrawCircleHole = enabled;
  }

  @override
  bool isDrawCircleHoleEnabled() {
    return mDrawCircleHole;
  }

  /**
   * Sets a custom IFillFormatter to the chart that handles the position of the
   * filled-line for each DataSet. Set this to null to use the default logic.
   *
   * @param formatter
   */
  void setFillFormatter(IFillFormatter formatter) {
    if (formatter == null)
      mFillFormatter = DefaultFillFormatter();
    else
      mFillFormatter = formatter;
  }

  @override
  IFillFormatter getFillFormatter() {
    return mFillFormatter;
  }
}

class PieData extends ChartData<IPieDataSet> {
  PieData(IPieDataSet dataSet) : super.fromList(List()..add(dataSet));

  /**
   * Sets the PieDataSet this data object should represent.
   *
   * @param dataSet
   */
  void setDataSet(IPieDataSet dataSet) {
    mDataSets.clear();
    mDataSets.add(dataSet);
    notifyDataChanged();
  }

  /**
   * Returns the DataSet this PieData object represents. A PieData object can
   * only contain one DataSet.
   *
   * @return
   */
  IPieDataSet getDataSet() {
    return mDataSets[0];
  }

  /**
   * The PieData object can only have one DataSet. Use getDataSet() method instead.
   *
   * @param index
   * @return
   */
  @override
  IPieDataSet getDataSetByIndex(int index) {
    return index == 0 ? getDataSet() : null;
  }

  @override
  IPieDataSet getDataSetByLabel(String label, bool ignorecase) {
    return ignorecase
        ? DartAdapterUtils.equalsIgnoreCase(label, mDataSets[0].getLabel())
            ? mDataSets[0]
            : null
        : (label == mDataSets[0].getLabel()) ? mDataSets[0] : null;
  }

  @override
  Entry getEntryForHighlight(Highlight highlight) {
    return getDataSet().getEntryForIndex(highlight.getX().toInt());
  }

  /**
   * Returns the sum of all values in this PieData object.
   *
   * @return
   */
  double getYValueSum() {
    double sum = 0;
    for (int i = 0; i < getDataSet().getEntryCount(); i++)
      sum += getDataSet().getEntryForIndex(i).getValue();
    return sum;
  }
}

class ScatterData extends BarLineScatterCandleBubbleData<IScatterDataSet> {
  ScatterData() : super();

  ScatterData.fromList(List<IScatterDataSet> dataSets)
      : super.fromList(dataSets);

  /**
   * Returns the maximum shape-size across all DataSets.
   *
   * @return
   */
  double getGreatestShapeSize() {
    double max = 0;

    for (IScatterDataSet set in mDataSets) {
      double size = set.getScatterShapeSize();

      if (size > max) max = size;
    }

    return max;
  }
}

class CandleData extends BarLineScatterCandleBubbleData<ICandleDataSet> {
  CandleData() : super();

  CandleData.fromList(List<ICandleDataSet> dataSets) : super.fromList(dataSets);
}

class BubbleData extends BarLineScatterCandleBubbleData<IBubbleDataSet> {
  BubbleData() : super();

  BubbleData.fromList(List<IBubbleDataSet> dataSets) : super.fromList(dataSets);

  /**
   * Sets the width of the circle that surrounds the bubble when highlighted
   * for all DataSet objects this data object contains, in dp.
   *
   * @param width
   */
  void setHighlightCircleWidth(double width) {
    for (IBubbleDataSet set in mDataSets) {
      set.setHighlightCircleWidth(width);
    }
  }
}

class CombinedData extends BarLineScatterCandleBubbleData<
    IBarLineScatterCandleBubbleDataSet<Entry>> {
  LineData mLineData;
  BarData mBarData;
  ScatterData mScatterData;
  CandleData mCandleData;
  BubbleData mBubbleData;

  CombinedData() : super();

  void setData1(LineData data) {
    mLineData = data;
    notifyDataChanged();
  }

  void setData2(BarData data) {
    mBarData = data;
    notifyDataChanged();
  }

  void setData3(ScatterData data) {
    mScatterData = data;
    notifyDataChanged();
  }

  void setData4(CandleData data) {
    mCandleData = data;
    notifyDataChanged();
  }

  void setData5(BubbleData data) {
    mBubbleData = data;
    notifyDataChanged();
  }

  @override
  void calcMinMax1() {
    if (mDataSets == null) {
      mDataSets = List();
    }
    mDataSets.clear();

    mYMax = -double.maxFinite;
    mYMin = double.maxFinite;
    mXMax = -double.maxFinite;
    mXMin = double.maxFinite;

    mLeftAxisMax = -double.maxFinite;
    mLeftAxisMin = double.maxFinite;
    mRightAxisMax = -double.maxFinite;
    mRightAxisMin = double.maxFinite;

    List<BarLineScatterCandleBubbleData> allData = getAllData();

    for (ChartData data in allData) {
      data.calcMinMax1();

      List<IBarLineScatterCandleBubbleDataSet<Entry>> sets = data.getDataSets();
      mDataSets.addAll(sets);

      if (data.getYMax1() > mYMax) mYMax = data.getYMax1();

      if (data.getYMin1() < mYMin) mYMin = data.getYMin1();

      if (data.getXMax() > mXMax) mXMax = data.getXMax();

      if (data.getXMin() < mXMin) mXMin = data.getXMin();

      if (data.mLeftAxisMax > mLeftAxisMax) mLeftAxisMax = data.mLeftAxisMax;

      if (data.mLeftAxisMin < mLeftAxisMin) mLeftAxisMin = data.mLeftAxisMin;

      if (data.mRightAxisMax > mRightAxisMax)
        mRightAxisMax = data.mRightAxisMax;

      if (data.mRightAxisMin < mRightAxisMin)
        mRightAxisMin = data.mRightAxisMin;
    }
  }

  BubbleData getBubbleData() {
    return mBubbleData;
  }

  LineData getLineData() {
    return mLineData;
  }

  BarData getBarData() {
    return mBarData;
  }

  ScatterData getScatterData() {
    return mScatterData;
  }

  CandleData getCandleData() {
    return mCandleData;
  }

  /**
   * Returns all data objects in row: line-bar-scatter-candle-bubble if not null.
   *
   * @return
   */
  List<BarLineScatterCandleBubbleData> getAllData() {
    List<BarLineScatterCandleBubbleData> data =
        List<BarLineScatterCandleBubbleData>();
    if (mLineData != null) data.add(mLineData);
    if (mBarData != null) data.add(mBarData);
    if (mScatterData != null) data.add(mScatterData);
    if (mCandleData != null) data.add(mCandleData);
    if (mBubbleData != null) data.add(mBubbleData);

    return data;
  }

  BarLineScatterCandleBubbleData getDataByIndex(int index) {
    return getAllData()[index];
  }

  @override
  void notifyDataChanged() {
    if (mLineData != null) mLineData.notifyDataChanged();
    if (mBarData != null) mBarData.notifyDataChanged();
    if (mCandleData != null) mCandleData.notifyDataChanged();
    if (mScatterData != null) mScatterData.notifyDataChanged();
    if (mBubbleData != null) mBubbleData.notifyDataChanged();

    calcMinMax1(); // recalculate everything
  }

  /**
   * Get the Entry for a corresponding highlight object
   *
   * @param highlight
   * @return the entry that is highlighted
   */
  @override
  Entry getEntryForHighlight(Highlight highlight) {
    if (highlight.getDataIndex() >= getAllData().length) return null;

    ChartData data = getDataByIndex(highlight.getDataIndex());

    if (highlight.getDataSetIndex() >= data.getDataSetCount()) return null;

    // The value of the highlighted entry could be NaN -
    //   if we are not interested in highlighting a specific value.

    List<Entry> entries = data
        .getDataSetByIndex(highlight.getDataSetIndex())
        .getEntriesForXValue(highlight.getX());
    for (Entry entry in entries)
      if (entry.y == highlight.getY() || highlight.getY().isNaN) return entry;

    return null;
  }

  /**
   * Get dataset for highlight
   *
   * @param highlight current highlight
   * @return dataset related to highlight
   */
  IBarLineScatterCandleBubbleDataSet<Entry> getDataSetByHighlight(
      Highlight highlight) {
    if (highlight.getDataIndex() >= getAllData().length) return null;

    BarLineScatterCandleBubbleData data =
        getDataByIndex(highlight.getDataIndex());

    if (highlight.getDataSetIndex() >= data.getDataSetCount()) return null;

    return data.getDataSets()[highlight.getDataSetIndex()];
  }

  int getDataIndex(ChartData data) {
    return getAllData().indexOf(data);
  }

  @override
  bool removeDataSet1(IBarLineScatterCandleBubbleDataSet<Entry> d) {
    List<BarLineScatterCandleBubbleData> datas = getAllData();
    bool success = false;
    for (ChartData data in datas) {
      success = data.removeDataSet1(d);
      if (success) {
        break;
      }
    }
    return success;
  }
}

class ScatterDataSet extends LineScatterCandleRadarDataSet<Entry>
    implements IScatterDataSet {
  /**
   * the size the scattershape will have, in density pixels
   */
  double mShapeSize = 15;

  /**
   * Renderer responsible for rendering this DataSet, default: square
   */
  IShapeRenderer mShapeRenderer = SquareShapeRenderer();

  /**
   * The radius of the hole in the shape (applies to Square, Circle and Triangle)
   * - default: 0.0
   */
  double mScatterShapeHoleRadius = 0;

  /**
   * Color for the hole in the shape.
   * Setting to `ColorUtils.COLOR_NONE` will behave as transparent.
   * - default: ColorUtils.COLOR_NONE
   */
  Color mScatterShapeHoleColor = ColorUtils.COLOR_NONE;

  ScatterDataSet(List<Entry> yVals, String label) : super(yVals, label);

  @override
  DataSet<Entry> copy1() {
    List<Entry> entries = List<Entry>();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(mValues[i].copy());
    }
    ScatterDataSet copied = ScatterDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is ScatterDataSet) {
      var scatterDataSet = baseDataSet as ScatterDataSet;
      scatterDataSet.mShapeSize = mShapeSize;
      scatterDataSet.mShapeRenderer = mShapeRenderer;
      scatterDataSet.mScatterShapeHoleRadius = mScatterShapeHoleRadius;
      scatterDataSet.mScatterShapeHoleColor = mScatterShapeHoleColor;
    }
  }

  /**
   * Sets the size in density pixels the drawn scattershape will have. This
   * only applies for non custom shapes.
   *
   * @param size
   */
  void setScatterShapeSize(double size) {
    mShapeSize = size;
  }

  @override
  double getScatterShapeSize() {
    return mShapeSize;
  }

  /**
   * Sets the ScatterShape this DataSet should be drawn with. This will search for an available IShapeRenderer and set this
   * renderer for the DataSet.
   *
   * @param shape
   */
  void setScatterShape(ScatterShape shape) {
    mShapeRenderer = getRendererForShape(shape);
  }

  /**
   * Sets a  IShapeRenderer responsible for drawing this DataSet.
   * This can also be used to set a custom IShapeRenderer aside from the default ones.
   *
   * @param shapeRenderer
   */
  void setShapeRenderer(IShapeRenderer shapeRenderer) {
    mShapeRenderer = shapeRenderer;
  }

  @override
  IShapeRenderer getShapeRenderer() {
    return mShapeRenderer;
  }

  /**
   * Sets the radius of the hole in the shape (applies to Square, Circle and Triangle)
   * Set this to <= 0 to remove holes.
   *
   * @param holeRadius
   */
  void setScatterShapeHoleRadius(double holeRadius) {
    mScatterShapeHoleRadius = holeRadius;
  }

  @override
  double getScatterShapeHoleRadius() {
    return mScatterShapeHoleRadius;
  }

  /**
   * Sets the color for the hole in the shape.
   *
   * @param holeColor
   */
  void setScatterShapeHoleColor(Color holeColor) {
    mScatterShapeHoleColor = holeColor;
  }

  @override
  Color getScatterShapeHoleColor() {
    return mScatterShapeHoleColor;
  }

  static IShapeRenderer getRendererForShape(ScatterShape shape) {
    switch (shape) {
      case ScatterShape.SQUARE:
        return SquareShapeRenderer();
      case ScatterShape.CIRCLE:
        return CircleShapeRenderer();
      case ScatterShape.TRIANGLE:
        return TriangleShapeRenderer();
      case ScatterShape.CROSS:
        return CrossShapeRenderer();
      case ScatterShape.X:
        return XShapeRenderer();
      case ScatterShape.CHEVRON_UP:
        return ChevronUpShapeRenderer();
      case ScatterShape.CHEVRON_DOWN:
        return ChevronDownShapeRenderer();
    }

    return null;
  }
}

class CandleDataSet extends LineScatterCandleRadarDataSet<CandleEntry>
    implements ICandleDataSet {
  /**
   * the width of the shadow of the candle
   */
  double mShadowWidth = 3;

  /**
   * should the candle bars show?
   * when false, only "ticks" will show
   * <p/>
   * - default: true
   */
  bool mShowCandleBar = true;

  /**
   * the space between the candle entries, default 0.1f (10%)
   */
  double mBarSpace = 0.1;

  /**
   * use candle color for the shadow
   */
  bool mShadowColorSameAsCandle = false;

  /**
   * paint style when open < close
   * increasing candlesticks are traditionally hollow
   */
  PaintingStyle mIncreasingPaintStyle = PaintingStyle.stroke;

  /**
   * paint style when open > close
   * descreasing candlesticks are traditionally filled
   */
  PaintingStyle mDecreasingPaintStyle = PaintingStyle.fill;

  /**
   * color for open == close
   */
  Color mNeutralColor = ColorUtils.COLOR_SKIP;

  /**
   * color for open < close
   */
  Color mIncreasingColor = ColorUtils.COLOR_SKIP;

  /**
   * color for open > close
   */
  Color mDecreasingColor = ColorUtils.COLOR_SKIP;

  /**
   * shadow line color, set -1 for backward compatibility and uses default
   * color
   */
  Color mShadowColor = ColorUtils.COLOR_SKIP;

  CandleDataSet(List<CandleEntry> yVals, String label) : super(yVals, label);

  @override
  DataSet<CandleEntry> copy1() {
    List<CandleEntry> entries = List<CandleEntry>();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(mValues[i].copy());
    }
    CandleDataSet copied = CandleDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is CandleDataSet) {
      var candleDataSet = baseDataSet as CandleDataSet;
      candleDataSet.mShadowWidth = mShadowWidth;
      candleDataSet.mShowCandleBar = mShowCandleBar;
      candleDataSet.mBarSpace = mBarSpace;
      candleDataSet.mShadowColorSameAsCandle = mShadowColorSameAsCandle;
      candleDataSet.mHighLightColor = mHighLightColor;
      candleDataSet.mIncreasingPaintStyle = mIncreasingPaintStyle;
      candleDataSet.mDecreasingPaintStyle = mDecreasingPaintStyle;
      candleDataSet.mNeutralColor = mNeutralColor;
      candleDataSet.mIncreasingColor = mIncreasingColor;
      candleDataSet.mDecreasingColor = mDecreasingColor;
      candleDataSet.mShadowColor = mShadowColor;
    }
  }

  @override
  void calcMinMax1(CandleEntry e) {
    if (e.getLow() < mYMin) mYMin = e.getLow();

    if (e.getHigh() > mYMax) mYMax = e.getHigh();

    calcMinMaxX1(e);
  }

  @override
  void calcMinMaxY1(CandleEntry e) {
    if (e.getHigh() < mYMin) mYMin = e.getHigh();

    if (e.getHigh() > mYMax) mYMax = e.getHigh();

    if (e.getLow() < mYMin) mYMin = e.getLow();

    if (e.getLow() > mYMax) mYMax = e.getLow();
  }

  /**
   * Sets the space that is left out on the left and right side of each
   * candle, default 0.1f (10%), max 0.45f, min 0f
   *
   * @param space
   */
  void setBarSpace(double space) {
    if (space < 0) space = 0;
    if (space > 0.45) space = 0.45;

    mBarSpace = space;
  }

  @override
  double getBarSpace() {
    return mBarSpace;
  }

  /**
   * Sets the width of the candle-shadow-line in pixels. Default 3f.
   *
   * @param width
   */
  void setShadowWidth(double width) {
    mShadowWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getShadowWidth() {
    return mShadowWidth;
  }

  /**
   * Sets whether the candle bars should show?
   *
   * @param showCandleBar
   */
  void setShowCandleBar(bool showCandleBar) {
    mShowCandleBar = showCandleBar;
  }

  @override
  bool getShowCandleBar() {
    return mShowCandleBar;
  }

  // TODO
  /**
   * It is necessary to implement ColorsList class that will encapsulate
   * colors list functionality, because It's wrong to copy paste setColor,
   * addColor, ... resetColors for each time when we want to add a coloring
   * options for one of objects
   *
   * @author Mesrop
   */

  /** BELOW THIS COLOR HANDLING */

  /**
   * Sets the one and ONLY color that should be used for this DataSet when
   * open == close.
   *
   * @param color
   */
  void setNeutralColor(Color color) {
    mNeutralColor = color;
  }

  @override
  Color getNeutralColor() {
    return mNeutralColor;
  }

  /**
   * Sets the one and ONLY color that should be used for this DataSet when
   * open <= close.
   *
   * @param color
   */
  void setIncreasingColor(Color color) {
    mIncreasingColor = color;
  }

  @override
  Color getIncreasingColor() {
    return mIncreasingColor;
  }

  /**
   * Sets the one and ONLY color that should be used for this DataSet when
   * open > close.
   *
   * @param color
   */
  void setDecreasingColor(Color color) {
    mDecreasingColor = color;
  }

  @override
  Color getDecreasingColor() {
    return mDecreasingColor;
  }

  @override
  PaintingStyle getIncreasingPaintStyle() {
    return mIncreasingPaintStyle;
  }

  /**
   * Sets paint style when open < close
   *
   * @param paintStyle
   */
  void setIncreasingPaintStyle(PaintingStyle paintStyle) {
    this.mIncreasingPaintStyle = paintStyle;
  }

  @override
  PaintingStyle getDecreasingPaintStyle() {
    return mDecreasingPaintStyle;
  }

  /**
   * Sets paint style when open > close
   *
   * @param decreasingPaintStyle
   */
  void setDecreasingPaintStyle(PaintingStyle decreasingPaintStyle) {
    this.mDecreasingPaintStyle = decreasingPaintStyle;
  }

  @override
  Color getShadowColor() {
    return mShadowColor;
  }

  /**
   * Sets shadow color for all entries
   *
   * @param shadowColor
   */
  void setShadowColor(Color shadowColor) {
    this.mShadowColor = shadowColor;
  }

  @override
  bool getShadowColorSameAsCandle() {
    return mShadowColorSameAsCandle;
  }

  /**
   * Sets shadow color to be the same color as the candle color
   *
   * @param shadowColorSameAsCandle
   */
  void setShadowColorSameAsCandle(bool shadowColorSameAsCandle) {
    this.mShadowColorSameAsCandle = shadowColorSameAsCandle;
  }
}

class BubbleDataSet extends BarLineScatterCandleBubbleDataSet<BubbleEntry>
    implements IBubbleDataSet {
  double mMaxSize = 0.0;
  bool mNormalizeSize = true;

  double mHighlightCircleWidth = 2.5;

  BubbleDataSet(List<BubbleEntry> yVals, String label) : super(yVals, label);

  @override
  void setHighlightCircleWidth(double width) {
    mHighlightCircleWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getHighlightCircleWidth() {
    return mHighlightCircleWidth;
  }

  @override
  void calcMinMax1(BubbleEntry e) {
    super.calcMinMax1(e);

    final double size = e.getSize();

    if (size > mMaxSize) {
      mMaxSize = size;
    }
  }

  @override
  DataSet<BubbleEntry> copy1() {
    List<BubbleEntry> entries = List<BubbleEntry>();
    for (int i = 0; i < mValues.length; i++) {
      entries.add(mValues[i].copy());
    }
    BubbleDataSet copied = BubbleDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BubbleDataSet) {
      var bubbleDataSet = baseDataSet as BubbleDataSet;
      bubbleDataSet.mHighlightCircleWidth = mHighlightCircleWidth;
      bubbleDataSet.mNormalizeSize = mNormalizeSize;
    }
  }

  @override
  double getMaxSize() {
    return mMaxSize;
  }

  @override
  bool isNormalizeSizeEnabled() {
    return mNormalizeSize;
  }

  void setNormalizeSizeEnabled(bool normalizeSize) {
    mNormalizeSize = normalizeSize;
  }
}
