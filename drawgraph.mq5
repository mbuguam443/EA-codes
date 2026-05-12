//+------------------------------------------------------------------+
//|                    DraggableMinimizableGraph.mq5                  |
//| A draggable and minimizable graph panel using CCanvas in MQL5     |
//+------------------------------------------------------------------+
#property strict

#include <Canvas/Canvas.mqh>

CCanvas canvas;

//-------------------------------------------------------------------
// Dummy data (replace with your strategy performance array later)
//-------------------------------------------------------------------
double values[] = {10, 25, 15, 40, 35, 60, 45, 80, 70, 90};

//-------------------------------------------------------------------
// Panel settings
//-------------------------------------------------------------------
string panelName    = "StrategyGraph";
int    panelX       = 20;
int    panelY       = 40;
int    panelWidth   = 600;
int    panelHeight  = 300;
int    headerHeight = 30;

// Margins
int marginLeft   = 60;
int marginRight  = 20;
int marginTop    = 10;
int marginBottom = 40;

//-------------------------------------------------------------------
// Drag state
//-------------------------------------------------------------------
bool isDragging = false;
int  dragOffsetX = 0;
int  dragOffsetY = 0;

//-------------------------------------------------------------------
// Minimize state
//-------------------------------------------------------------------
bool isMinimized = false;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!CreatePanel(panelWidth, panelHeight))
      return(INIT_FAILED);

   // Enable mouse move events
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   DrawPanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);

   canvas.Destroy();
   ObjectDelete(0, panelName);
}

//+------------------------------------------------------------------+
//| Create/Recreate the panel                                        |
//+------------------------------------------------------------------+
bool CreatePanel(int width, int height)
{
   canvas.Destroy();
   ObjectDelete(0, panelName);

   if(!canvas.CreateBitmapLabel(0, 0, panelName,
                                panelX, panelY,
                                width, height))
   {
      Print("Failed to create panel");
      return(false);
   }

   // Keep panel fixed on the screen
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);

   return(true);
}

//+------------------------------------------------------------------+
//| Handle mouse events                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // ---------------------------------------------------------------
   // Click on header toggles minimize/restore
   // ---------------------------------------------------------------
   if(id == CHARTEVENT_CLICK)
   {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;

      if(IsInHeader(mouseX, mouseY))
      {
         isMinimized = !isMinimized;
         DrawPanel();
         return;
      }
   }

   // ---------------------------------------------------------------
   // Mouse move used for dragging
   // ---------------------------------------------------------------
   if(id != CHARTEVENT_MOUSE_MOVE)
      return;

   int mouseX = (int)lparam;
   int mouseY = (int)dparam;

   // Left mouse button state is in bit 0
   bool leftPressed = ((StringToInteger(sparam) & 1) == 1);

   // Start dragging only when the header is pressed
   if(!isDragging && leftPressed)
   {
      if(IsInHeader(mouseX, mouseY))
      {
         isDragging = true;
         dragOffsetX = mouseX - panelX;
         dragOffsetY = mouseY - panelY;
      }
   }

   // Move the panel
   if(isDragging && leftPressed)
   {
      panelX = mouseX - dragOffsetX;
      panelY = mouseY - dragOffsetY;

      // Keep panel within visible area
      if(panelX < 0) panelX = 0;
      if(panelY < 0) panelY = 0;

      // Reposition the bitmap label
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, panelY);

      ChartRedraw();
   }

   // Stop dragging when mouse button is released
   if(isDragging && !leftPressed)
      isDragging = false;
}

//+------------------------------------------------------------------+
//| Check if mouse is inside the title bar                           |
//+------------------------------------------------------------------+
bool IsInHeader(int mouseX, int mouseY)
{
   return (mouseX >= panelX &&
           mouseX <= panelX + panelWidth &&
           mouseY >= panelY &&
           mouseY <= panelY + headerHeight);
}

//+------------------------------------------------------------------+
//| Draw the entire panel                                            |
//+------------------------------------------------------------------+
void DrawPanel()
{
   int currentHeight = isMinimized ? headerHeight : panelHeight;

   // Recreate panel with new size
   if(!CreatePanel(panelWidth, currentHeight))
      return;

   // Background
   canvas.Erase(ColorToARGB(clrBlack, 220));

   // Title bar
   canvas.FillRectangle(0, 0,
                        panelWidth - 1, headerHeight - 1,
                        ColorToARGB(clrDarkSlateGray));

   // Border
   canvas.Rectangle(0, 0,
                    panelWidth - 1, currentHeight - 1,
                    ColorToARGB(clrGray));

   // Title
   canvas.TextOut(10, 8,
                  "Strategy Performance",
                  ColorToARGB(clrWhite));

   // Minimize/restore symbol
   canvas.TextOut(panelWidth - 20, 8,
                  isMinimized ? "+" : "-",
                  ColorToARGB(clrYellow));

   // If minimized, update and exit
   if(isMinimized)
   {
      canvas.Update();
      return;
   }

   // Draw graph contents
   DrawGraph();

   // Show on screen
   canvas.Update();
}

//+------------------------------------------------------------------+
//| Draw graph area                                                  |
//+------------------------------------------------------------------+
void DrawGraph()
{
   int size = ArraySize(values);
   if(size < 2)
      return;

   // Find min and max
   double minVal = values[0];
   double maxVal = values[0];

   for(int i = 1; i < size; i++)
   {
      if(values[i] < minVal) minVal = values[i];
      if(values[i] > maxVal) maxVal = values[i];
   }

   if(maxVal == minVal)
      maxVal = minVal + 1.0;

   double midVal = (minVal + maxVal) / 2.0;

   // Graph area
   int graphLeft   = marginLeft;
   int graphTop    = headerHeight + marginTop;
   int graphRight  = panelWidth - marginRight;
   int graphBottom = panelHeight - marginBottom;

   int graphWidth  = graphRight - graphLeft;
   int graphHeight = graphBottom - graphTop;

   // Graph border
   canvas.Rectangle(graphLeft, graphTop,
                    graphRight, graphBottom,
                    ColorToARGB(clrDimGray));

   // Current value
   string currentText =
      "Current: " + DoubleToString(values[size - 1], 2);

   canvas.TextOut(panelWidth - 170, 8,
                  currentText,
                  ColorToARGB(clrLime));

   // Grid lines
   for(int i = 0; i <= 4; i++)
   {
      int y = graphTop + (i * graphHeight) / 4;

      canvas.Line(graphLeft, y,
                  graphRight, y,
                  ColorToARGB(clrDimGray));
   }

   // Y-axis labels
   canvas.TextOut(5, graphTop - 5,
                  DoubleToString(maxVal, 2),
                  ColorToARGB(clrWhite));

   canvas.TextOut(5, graphTop + graphHeight / 2 - 5,
                  DoubleToString(midVal, 2),
                  ColorToARGB(clrWhite));

   canvas.TextOut(5, graphBottom - 5,
                  DoubleToString(minVal, 2),
                  ColorToARGB(clrWhite));

   // X-axis labels
   canvas.TextOut(graphLeft, graphBottom + 10,
                  "0",
                  ColorToARGB(clrWhite));

   canvas.TextOut(graphRight - 25, graphBottom + 10,
                  IntegerToString(size - 1),
                  ColorToARGB(clrWhite));

   // Draw the line graph
   double stepX = (double)graphWidth / (size - 1);

   for(int i = 1; i < size; i++)
   {
      int x1 = graphLeft + (int)((i - 1) * stepX);
      int x2 = graphLeft + (int)(i * stepX);

      double norm1 =
         (values[i - 1] - minVal) / (maxVal - minVal);

      double norm2 =
         (values[i] - minVal) / (maxVal - minVal);

      int y1 = graphBottom - (int)(norm1 * graphHeight);
      int y2 = graphBottom - (int)(norm2 * graphHeight);

      // Line segment
      canvas.Line(x1, y1, x2, y2,
                  ColorToARGB(clrLime));

      // Point markers
      canvas.Circle(x1, y1, 2,
                    ColorToARGB(clrYellow));

      if(i == size - 1)
         canvas.Circle(x2, y2, 2,
                       ColorToARGB(clrYellow));
   }
}