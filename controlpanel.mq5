#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|includes                                                          |
//+------------------------------------------------------------------+
#define  PANEL_NAME "Demo app"
#define  PANEL_HEIGHT 200
#define  PANEL_WIDTH 350

#define  BTN1_NAME "button 1"
#define  BTN1_HEIGHT 50
#define  BTN1_WIDTH 50

#define  BTN2_NAME "button 2"
#define  BTN2_HEIGHT 50
#define  BTN2_WIDTH 50

#include<Controls/Dialog.mqh>
#include<Controls/Button.mqh>
CAppDialog app;
CButton btn1;
CButton btn2;



int OnInit()
  {
    app.Create(0,PANEL_NAME,0,20,20,20+PANEL_WIDTH,20+PANEL_HEIGHT);
    btn1.Create(0,BTN1_NAME,0,0,0,0,0);
    btn1.Text("Buy");
    btn1.Width(PANEL_WIDTH/2);
    btn1.Height(90);
    btn2.Create(0,BTN2_NAME,0,  PANEL_WIDTH/2, 20  ,0,0);
    btn2.Text("Sell");
    btn2.Width(PANEL_WIDTH/2);
    btn2.Height(90);
    app.Add(btn1);
    app.Add(btn2);
    app.Run();
    
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    app.Destroy();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   
  }
//+------------------------------------------------------------------+

void OnChartEvent(const int32_t id,const long& lparam,const double& dparam,const string& sparam)
  {
   app.ChartEvent(id,lparam,dparam,sparam);
  if(id==CHARTEVENT_OBJECT_CLICK)
    {
      if(sparam==btn1.Name())
        {
         Print("you click button one");
        }
    }
  }