#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     
     
     if(isNewsEventAhead())
     {
      Print("News are Ahead so Stop Trading");
     }
   
  }


bool isNewsEventAhead()
{
   MqlCalendarValue value[];
     datetime startTime=iTime(_Symbol,PERIOD_CURRENT,0);
     datetime endTime=startTime+PeriodSeconds(PERIOD_D1);
     CalendarValueHistory(value,startTime,endTime,NULL,NULL);
     
     
     
     for(int i=0;i<ArraySize(value);i++)
       {
         MqlCalendarEvent event;
         CalendarEventById(value[i].event_id,event);
         MqlCalendarCountry country;
         CalendarCountryById(event.country_id,country);
         
         string mysymbol=_Symbol;
         if(StringFind(mysymbol,country.currency)<0)continue;
         if(event.importance==CALENDAR_IMPORTANCE_LOW)continue;
         if(event.importance==CALENDAR_IMPORTANCE_NONE)continue;
         
         if(TimeCurrent()>=value[i].time-15*PeriodSeconds(PERIOD_M1) && TimeCurrent()<value[i].time+15*PeriodSeconds(PERIOD_M1))
           {
            Print("News Ahead !!!!!!!");
            return true;
           }
         Print(event.name," => ", value[i].actual_value/1000000);
       }
       
       return false;
}
