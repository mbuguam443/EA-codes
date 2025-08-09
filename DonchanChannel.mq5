#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|Indicator Properties                                              |
//+------------------------------------------------------------------+

#property indicator_chart_window    //this mean it will be shown on main chart window
#property indicator_buffers 2
#property indicator_plots   2
//+------------------------------------------------------------------+
//|inputs                                                            |
//+------------------------------------------------------------------+
input  int InpPeriod   =20;         //Period
input  int InpOffset   =0;          //Offset %of the channel
input  color InpColor  =clrBlue;    //color
//+------------------------------------------------------------------+
//|Global Variable                                                   |
//+------------------------------------------------------------------+
double bufferUpper[];
double bufferLower[];
double upper,lower;
int first,bar;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //initialize buffer
   initializeBuffer(0,bufferUpper,"Donchian Upper");
   initializeBuffer(1,bufferLower,"Donchian Lower");
   IndicatorSetString(INDICATOR_SHORTNAME,"Donchian ("+IntegerToString(InpPeriod)+")");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[]){
                
                
                if(rates_total<InpPeriod+1){return 0;}
                first=prev_calculated==0?InpPeriod : prev_calculated-1;
               
               for(bar=first;bar<rates_total;bar++)
                 {
                   upper=open[ArrayMaximum(open,bar-InpPeriod+1,InpPeriod)];
                   lower=open[ArrayMinimum(open,bar-InpPeriod+1,InpPeriod)];
                   
                   bufferUpper[bar]=upper-(upper-lower)*InpOffset*0.01;
                   bufferLower[bar]=lower+(upper-lower)*InpOffset*0.01;
                 }   
                

   return(rates_total);
  }
//+------------------------------------------------------------------+
//|custom functions                                                  |
//+------------------------------------------------------------------+

void initializeBuffer(int index ,double &buffer[], string label)
{
    SetIndexBuffer(index,buffer,INDICATOR_DATA);
    PlotIndexSetInteger(index,PLOT_DRAW_TYPE,DRAW_LINE);
    PlotIndexSetInteger(index,PLOT_LINE_WIDTH,2);
    PlotIndexSetInteger(index,PLOT_DRAW_BEGIN,InpPeriod-1);
    PlotIndexSetInteger(index,PLOT_SHIFT,1);
    PlotIndexSetInteger(index,PLOT_LINE_COLOR,InpColor);
    PlotIndexSetString(index,PLOT_LABEL,label);
    PlotIndexSetDouble(index,PLOT_EMPTY_VALUE,EMPTY_VALUE);
}

