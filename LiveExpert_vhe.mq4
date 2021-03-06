//+------------------------------------------------------------------------------------+
//|                                               LiveExpert_vhe.mq4                   |
//|                   Copyright 2016 Севастьянов Семен Владимирович, semen_s84@mail.ru |
//|                                              http://fx-fixprice.ru                 |
//+------------------------------------------------------------------------------------+
#property copyright   "2016 Севастьянов Семен Владимирович, semen_s84@mail.ru"
#property link        "http://fx-fixprice.ru"
#property description "LiveExpert virtual hosting edition V.1.0.7"

#define MAGICMA  710400692
//--- Inputs
// 1 пипс может быть либо равен 1 пункту либо быть 1/10 от величины пункта в зависимости от типа счета //
input double Lots                       = 0.01;     // Объем сделки (лот)
input int    LotCount                   = 3;        // Максимальное кол-во сделок

input int    MovingPeriod_m1            = 14;       // Период 1-й MA для анализа точки входа
input int    MovingPeriod_m2            = 79;       // Период 2-й MA для анализа точки входа
 
input int    StopLoss                   = 3500*5;   // Фиксированный стоп лосс в пипсах
input int    TakeProffit                = 3500;     // Фиксированный тейк профит в пипсах
input double TrailingStop               = 300;      // Трайлинг в пипсах

input int    Sensivity                  = 130;      // Чувствительность сигнала в пипсах
input int    ShiftInputPoint            = 0;        // Сдвиг в пипсах от точки где хотел бы взять ордер робот
input int    RiskOffPoint               = 450;      // Риск в пипсах (сколько пипсов от точки входа должна оттойти цена для включения механизма трайлинга или безубытка)

input int    disable_signal_buy         = 1;        // Вкл./Выкл. сигналов на покупку
input int    disable_signal_sell        = 0;        // Вкл./Выкл. сигналов на продажу
input int    disable_trailing           = 0;        // Вкл./Выкл. механизма трайлинг стоп
input bool   closeallorders             = false;    // Вкл. срипта закрывающего все открытые ордера (выполняется с подтверждением пользователя)
input bool   write_to_file_power_signal = true;     // записывать в файл тек. силу сигнала (мощность сигнала)
input int    GMT                        = 5;        // GMT+5
input int    tiks_for_refresh           = 100;      // кол-во тиков для обновления информации о силе сигнала и другой инф.
input int    level_signal_to_trade      = 10;       // уровень (мощность) сигнала при котором совершается сделка, может быть от 1..11, рекомендуется устанавливать значение >= 5
input int    level_avg_signal_to_trade  = 6;        // уровень среднего сигнала при котором совершается сделка, (берется среднее значение "мощности сигнала" среди всех таймфреймов)
input int    ShiftForNextOpenPoint      = 200;
// имя файла для сохранения информации о сопровождении сделок (открытии/закрытии/модификации ордеров)
input string orders_file_name           = "orders.csv";  
// тоже самое но для работы в режиме тестера
input string orders_file_name_tester    = "orders_tester.csv";  
// имя файла для сохранения информации о закрытых ордерах
input string orders_close_file_name     = "close_orders.csv";  

// имя файла для сохранения информации о мощности сигнала и другой полезной информации
input string powersignal_file_name      = "power_signal.csv";
// тоже самое но для работы в режиме тестера
input string powersignal_file_name_tester = "power_signal_tester.csv";

// для определения момента закрытия ордера, запомним сколько сейчас ордеров в истории
int     history_count              = 0;


bool    close_all_openorders       = closeallorders;
double  input_price_sell           = 0.0;
double  input_price_buy            = 0.0;
int     _TakeProffit               = 0.0;
int     _StopLoss                  = 0.0;
bool    refresh                    = true;
// записываем период по которому работаем
int     sPeriod                    = 0;
// Робот проходит по всем таймфреймам и суммирует мощность сигнала, значение записывается в эту переменную "SUMM_SIGNAL"
int     SUMM_SIGNAL                = 0; 
// -- локальные переменные для механизма защиты входных параметров робота от неправильной установки --
int     _level_avg_signal_to_trade = level_avg_signal_to_trade; // -- значение должно быть больше 0 и меньше либо равно 10
int     _level_signal_to_trade     = level_signal_to_trade;     // -- значение должно быть болшье 3 и меньше либо равно 11

int     len_array_op_points = 10;
double  _Array_open_points[10]; 
int     _Array_open_ticket[10];
string  _Array_open_Symbol[10];

//---  RSI ---
int     RSI_Period     = 8;
int     sum_index_rsi  = 0;
int     sum_index_ac   = 0;
int     count_for_avg  = 0;
//------------

//+------------------------------------------------------------------+
//| Функция определения глубины тренда                               |
//+------------------------------------------------------------------+
void depth_trend()
  {
//--- определение индекса на покупку
   double rsi=iRSI(Symbol(), sPeriod, RSI_Period, PRICE_CLOSE,0);
   int index_rsi = 0;
   if(rsi>90.0) 
      index_rsi=4;
   else if(rsi>80.0)
      index_rsi=3;
   else if(rsi>70.0)
      index_rsi=2;
   else if(rsi>60.0)
      index_rsi=1;
   else if(rsi<10.0)
      index_rsi=-4;
   else if(rsi<20.0)
      index_rsi=-3;
   else if(rsi<30.0)
      index_rsi=-2;
   else if(rsi<40.0)
      index_rsi=-1;
   sum_index_rsi = sum_index_rsi + index_rsi;   
   
   if (refresh && (Period() == sPeriod)) 
        Print("*** RSI DEPTH_TREND_SUM: ", sum_index_rsi, " ***", " *** avg_value: ", round(sum_index_rsi/count_for_avg));
  }
//+------------------------------------------------------------------+
//| Функция определения скорости тренда                              |
//+------------------------------------------------------------------+
void speed_ac()
  {
   double ac[];
   ArrayResize(ac,5);
   for(int i=0; i<5; i++)
      ac[i]=iAC(Symbol(), sPeriod, i);

   int index_ac=0;
//--- сигнал на покупку
   if(ac[0] > ac[1] && ac[1]<=ac[2])
      index_ac=1;
   else if(ac[0]>ac[1] && ac[1]>ac[2] && ac[2]<=ac[3])
      index_ac=2;
   else if(ac[0]>ac[1] && ac[1]>ac[2] && ac[2]>ac[3] && ac[3]<=ac[4])
      index_ac=3;
   else if(ac[0]>ac[1] && ac[1]>ac[2] && ac[2]>ac[3] && ac[3]>ac[4])
      index_ac=4;
//--- сигнал на продажу
   else if(ac[0]<ac[1] && ac[1]>=ac[2])
      index_ac=-1;
   else if(ac[0]<ac[1] && ac[1]<ac[2] && ac[2]>=ac[3])
      index_ac=-2;
   else if(ac[0]<ac[1] && ac[1]<ac[2] && ac[2]<ac[3] && ac[3]>=ac[4])
      index_ac=-3;
   else if(ac[0]<ac[1] && ac[1]<ac[2] && ac[2]<ac[3] && ac[3]<ac[4])
      index_ac=-4;
   sum_index_ac = sum_index_ac + index_ac; 
   
   if (refresh && (Period() == sPeriod)) 
    {
      Print("*** RSI SPEED_AC_SUM: ", sum_index_ac, " ***, cnt_for_avg: ", count_for_avg, " *** avg_value: ", round(sum_index_ac/count_for_avg));
      if (Sell()) 
      {
        Print("*** RSI SIGNAL SELL! *** RSI SIGNAL SELL! *** RSI SIGNAL SELL!*** ");
      }   
      if (Buy())
      {
        Print("*** RSI SIGNAL BUY! *** RSI SIGNAL BUY! *** RSI SIGNAL BUY!*** ");
      }
    }
  }
//+------------------------------------------------------------------+
//| Функция проверки условия на покупку                              |
//+------------------------------------------------------------------+
bool Buy()
  {
   bool res = false;
   if (count_for_avg==0) count_for_avg = 1;
   if((round(sum_index_rsi/count_for_avg)==2 && 
       round(sum_index_ac/count_for_avg) >=1) || 
       (
        round(sum_index_rsi/count_for_avg)==3 && 
        round(sum_index_ac/count_for_avg)==1
       )
     )
      res = true;
   return (res);
  }
//+------------------------------------------------------------------+
//| Функция проверки условия на продажу                              |
//+------------------------------------------------------------------+
bool Sell()
  {
   bool res=false;
   if((round(sum_index_rsi/count_for_avg)==-2 && round(sum_index_ac/count_for_avg)<=-1) || 
      (round(sum_index_rsi/count_for_avg)==-3 && round(sum_index_ac/count_for_avg)==-1))
      res=true;
   return (res);
  }

//*************************************************//
// Процедура для создания заголовка CSV файла  ****//
//*************************************************// 
void WriteFileHeader(int h)
{
  FileWrite(h, "Time",
               "Type",
               "Ticket",
               "Lots",
               "Symbol",
               "OpenPrice",
               "StopLoss",
               "Profit",
               "TakeProfit",
               "BID",
               "OrdersTotal",
               "ACCOUNT_NAME",
               "ACCOUNT_LOGIN",
               "ACCOUNT_BALANCE"
           );   

}

//*******************************//
// Пример процедуры сохр. инф.   //
// о выбранном ордере            //
//*******************************//
void WriteFileOrderInf
      (
       int    file_handle, 
       string order_type
      )
{
  FileWrite(file_handle, 
            TimeToString(TimeGMT() + 3600*GMT, TIME_DATE | TIME_SECONDS), 
            order_type,
            OrderTicket(),
            OrderLots(), 
            OrderSymbol(), 
            OrderOpenPrice(), 
            OrderStopLoss(), 
            DoubleToStr(OrderProfit(), 5), 
            OrderTakeProfit(),
            MarketInfo(OrderSymbol(),MODE_BID), 
            OrdersTotal(), 
            AccountInfoString(ACCOUNT_NAME), 
            AccountInfoInteger(ACCOUNT_LOGIN), 
            AccountInfoDouble(ACCOUNT_BALANCE)
           );
}

///////////////////////////////////////////////////
// Объявляем функцию для записи данных в файл    //
// Записываем информации о сопровождении сделок  //
///////////////////////////////////////////////////
int SaveOpenOrders(
     string file_name
      )
{ 
 int h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
 if (h<= 0) h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
  
 if (h > 0) {
  if (FileIsEnding(h)) WriteFileHeader(h);
  
  FileSeek(h, 0, SEEK_END);
  int index_array = 0;
  int total=OrdersTotal(); 
    for(int cnt1=0;cnt1<total;cnt1++)
     {
       if(!OrderSelect(cnt1,SELECT_BY_POS,MODE_TRADES))
         continue;
       if(OrderType()==OP_BUY)
       {  
         // Ордер на покупку
         WriteFileOrderInf(h, "BUY");
         // Записываем точки входа по открытым ордерам
         // чтобы повторно не открывать в той же самой точке новый ордер до момента
         // закрытия старого ордера  
          if (index_array < len_array_op_points)
           {
             _Array_open_points[index_array] = OrderOpenPrice();    
             _Array_open_ticket[index_array] = OrderTicket();
             _Array_open_Symbol[index_array] = OrderSymbol();
             index_array++;
           }  
       } else
       {
         if (OrderType()==OP_SELL)
         {
          // Ордер на продажу
           WriteFileOrderInf(h, "SELL");            
          // Записываем точки входа по открытым ордерам
          // чтобы повторно не открывать в той же самой точке новый ордер до момента
          // закрытия старого ордера  
          if (index_array < len_array_op_points)
           {
             _Array_open_points[index_array] = OrderOpenPrice();    
             _Array_open_ticket[index_array] = OrderTicket();
             _Array_open_Symbol[index_array] = OrderSymbol();
             index_array++;
           }  
         }
        if (OrderType()==OP_SELLLIMIT) 
         {
            // Ордер отложенный на продажу
            WriteFileOrderInf(h, "SELLLIMIT");            
         }  
        if (OrderType()==OP_SELLSTOP) 
         {
           // Ордер отложенный на продажу
           WriteFileOrderInf(h, "SELLSTOP");      
         } // end if OrderType()==OP_SELLSTOP             
       } // else
     } // end  for(int cnt1=0;cnt1<total;cnt1++)
  
  FileClose(h);
  return(1);
 }
 return(0);
}

//************************************************************************//
// Теперь реализуем функцию сохранения информации о закрытых ордерах *****//
//************************************************************************//
int SaveOrderByTicket
      (
      string file_name,
      int    Ticket
      )
{
 int h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
 if (h<= 0) h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
  
 if (h > 0) {
  if (FileIsEnding(h))  WriteFileHeader(h);
  //************************************************************************************************//
  FileSeek(h, 0, SEEK_END);
  if (OrderSelect(Ticket, SELECT_BY_TICKET))
  {
     if(OrderType()==OP_BUY)
       {  
         // Ордер на покупку
         WriteFileOrderInf(h, "BUY");               
       } else
       {
         if (OrderType()==OP_SELL)
         {
            // Ордер на продажу
            WriteFileOrderInf(h, "SELL");                                   
         }
         if (OrderType()==OP_SELLLIMIT) 
         {
            // Ордер отложенный на продажу           
            WriteFileOrderInf(h,"SELLLIMIT");
         }  
         if (OrderType()==OP_SELLSTOP) 
         {
            // Ордер отложенный на продажу
            WriteFileOrderInf(h, "SELLSTOP");
         } // end if OrderType()==OP_SELLSTOP             
       } // end else if(OrderType()==OP_BUY) 
  } // end if OrderSelect(Ticket, SELECT_BY_TICKET)   
  //************************************************************************************************//
  FileClose(h);
  return(1);
 }
 return(0); 
}

// Объявляем функцию для записи данных в файл
int SavePowerSignal(
     int    sell_buy,
     double power_signal,
      )
{ 
 string file_name = powersignal_file_name;
 if (IsTesting())
 {
   file_name = powersignal_file_name_tester;
 }
 
 int h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
 if (h<= 0) h = FileOpen(file_name, FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE, ';');
 
 if (input_price_sell == 0) get_price_sell();
   
 if (h > 0) { 
  if (FileIsEnding(h)) // -- функция определяет конец файла 
  FileWrite(h, "power_signal", "symbol", "period", "bid", "ask", "time", "input_price", "sell_buy", "OrdersTotal", "ACCOUNT_NAME", "ACCOUNT_LOGIN", "ACCOUNT_BALANCE", "SUMM_SIGNAL");      
  
  FileSeek(h, 0, SEEK_END);
  
  double vbid    = MarketInfo(Symbol(),MODE_BID); 
  double vask    = MarketInfo(Symbol(),MODE_ASK); 
  
  //string str1 = AccountInfoString(ACCOUNT_PROFIT);
   
  if (power_signal > 0)        
  FileWrite(h, power_signal, Symbol(), sPeriod, DoubleToStr(vbid, 5), DoubleToStr(vask, 5), TimeToString(TimeGMT() + 3600*GMT, TIME_DATE | TIME_SECONDS), DoubleToStr(input_price_sell, 5), sell_buy, OrdersTotal(), AccountInfoString(ACCOUNT_NAME), AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoDouble(ACCOUNT_BALANCE), SUMM_SIGNAL); 
  
  FileClose(h);
  return(1);
 }
 return(0);
}

//////////////////////////////////////////
// стандартная математическая функция   //
// модуль числа                         //     
//////////////////////////////////////////
double abs(double value)
{
  if (value > 0)
  {  
   return value;
  } else
  {
  return -1*value;
  }
}


//////////////////////////////////////
// Calculate optimal lot size       //                                
//////////////////////////////////////
double LotsOptimized()
  {
   double lot=Lots;
   return(lot);
  }

/////////////////////////////////////
// Расчет оптимальной точки входа  //
// для следки на продажу           //
///////////////////////////////////// 
double get_price_sell()
  {
       input_price_sell = Close[1] + ShiftInputPoint*Point;
      _TakeProffit     = TakeProffit;
      _StopLoss        = StopLoss;
      if (_StopLoss > StopLoss || _StopLoss < 10) {_StopLoss = StopLoss;}      
 
    for(int y=0;y<len_array_op_points;y++)
    {
      if (
         (_Array_open_points[y]+ ShiftForNextOpenPoint*Point  
                                 >  input_price_sell) 
                                 && 
         (_Array_open_Symbol[y]  == Symbol())
         )
      {
        input_price_sell = 0; 
      }
    }      
    
    if (refresh && (Period() == sPeriod)) 
        Print("*** input_price_sell: ", input_price_sell, " ***");
        
    return(input_price_sell);    
  } 
  
//////////////////////////////////////  
// сигнал на продажу                //
//////////////////////////////////////
bool signal_sell(double ma14_1, double ma14_2, double ma14_3, double ma26_1, double ma26_2, double ma26_3)
{

  if (disable_signal_sell == 1) 
   {
    input_price_sell = 0;
    return false;
   } 
  
  double spread = abs(Ask-Bid);
  //*** В последствии нужно подобное запихать в функцию, типа инициализация тайм фрейма *** 
  int val_index_close = iLowest(NULL, sPeriod, MODE_CLOSE, 10, 0); 
  int val_index_open  = iLowest(NULL, sPeriod, MODE_OPEN,  10, 0); 
  int val_index_low   = iLowest(NULL, sPeriod, MODE_LOW,   10, 0); 
  int val_index_high  = iLowest(NULL, sPeriod, MODE_HIGH,  10, 0); 
  //*** ***********************************************************************************
   
   int power_signal_sell = 0;
   if ((Open[2]  < Close[2]) && (refresh))
   {
     if (Period()==sPeriod) Print("compare №1 true");
     power_signal_sell++;
   } else
   {
      if (refresh && Period()==sPeriod) {
        Print("1: Open[2]  < Close[2]");
        Print("1: Open[2]= ",  Open[2]);
        Print("1: Close[2]= ", Close[2]);
      }
   }
   
   if ((abs(Close[2] - Open[1]) < Sensivity*Point) && (refresh))
   {
     if (Period()==sPeriod) Print("compare №2 true");
     power_signal_sell++;
   } else
   {
      if (refresh && Period()==sPeriod) 
      {
        Print("2: abs(Close[2] - Open[1]) < Sensivity*Point");
        Print("2: abs(Close[2] - Open[1])= ", abs(Close[2] - Open[1]));
        Print("2: Sensivity*Point= ", Sensivity*Point);
      }
   }
   
   if ((Open[1]  < Close[1]) && (refresh))
   {
     if (Period()==sPeriod) Print("compare №3 true");
     power_signal_sell++;
   } else
   {
    if (refresh && Period()==sPeriod) 
      {
        Print("3: Open[1]  < Close[1]");
        Print("3: Open[1]= ",  Open[1]);
        Print("3: Close[1]= ", Close[1]);
      }
   }
   
   if ( Low[2] < ma14_1 && refresh)
   {
     if (Period()==sPeriod) Print("compare №4 true");
     power_signal_sell++;
   } else
   {
      if (refresh && Period()==sPeriod) 
      {
        Print("4: Low[2] < ma14_1");
        Print("4: Low[2]= ", Low[2]);
        Print("4: ma14_1= ", ma14_1);
      }
   }
   
   if (  High[2] > ma14_1 && refresh)
   {
     if (Period()==sPeriod) Print("compare №5 true");
     power_signal_sell++;
   } else
   {
      if (refresh && Period()==sPeriod) 
      {
        Print("5: High[2] > ma14_1");
        Print("5: High[2]= ", High[2]);
        Print("5: ma14_1= ", ma14_1);
      }
   }
   
   if (  (Close[1] - Open[1]) > 100 * Point && refresh)
   {
     if (Period()==sPeriod) Print("compare №6 true");
     power_signal_sell++;
   } else
   {
     if (refresh && Period()==sPeriod) 
     {
       Print("6: (Close[1] - Open[1]) > 100 * Point");
       Print("6: Close[1] - Open[1]= ", (Close[1] - Open[1]));
       Print("6: 100 * Point= ", 100 * Point);
     }
   }
   
   if (  (Open[1] > ma14_1) && refresh)
   {
     if (Period()==sPeriod) Print("compare №7 true");
     power_signal_sell++;
   } else
   {
     if (refresh && Period()==sPeriod) 
     {
       Print("7: Open[1] > ma14_1");
       Print("7: Open[1]= ", Open[1]);
       Print("7: ma14_1= ", ma14_1);
     }
   }
   
   if (  (Close[1] > ma14_1)  && refresh)
   {
     if (Period()==sPeriod) Print("compare №8 true");
     power_signal_sell++;
   }
   
   if (  ( Open[2] > ma14_1)  && refresh)
   {
     if (Period()==sPeriod) Print("compare №9 true");
     power_signal_sell++;
   } else
   {
    if (refresh && Period()==sPeriod) 
     {
       Print("9: Open[2] > ma14_1");
       Print("9: Open[2]= ", Open[2]);
       Print("9: ma14_1= ", ma14_1);
     }
   }
   
   if (  (Close[2] > ma14_1)  && refresh)
   {
     if (Period()==sPeriod) Print("compare №10 true");
     power_signal_sell++;
   } else
   {
    if (refresh && Period()==sPeriod) 
     {
       Print("10: Close[2] > ma14_1");
       Print("10: Close[2]= ", Close[2]);
       Print("10: ma14_1= ", ma14_1);
     }
   }
   
   if (  (ma14_3   > ma26_3)  && refresh)
   {
     if (Period()==sPeriod) Print("compare №11 true");
     power_signal_sell++;
   } else
   {
     if (refresh && Period()==sPeriod) 
     {
       Print("11: ma14_3   > ma26_3");
       Print("11: ma14_3= ", ma14_3);
       Print("11: ma26_3= ", ma26_3);
     }
   }
   
   if (Sell() && refresh)
   {
     if (Period()==sPeriod) Print("compare №12 true");
     power_signal_sell++;
   }
    
    if (refresh && Period()==sPeriod) 
     {
       Print("*** ", power_signal_sell, " ***");
       Print("Файл должен быть создан в папке "+TerminalInfoString(TERMINAL_COMMONDATA_PATH));
     }
   if (Period()!=sPeriod) {SUMM_SIGNAL = SUMM_SIGNAL + power_signal_sell;}  
   if (write_to_file_power_signal && Period()==sPeriod) SavePowerSignal(1, power_signal_sell);
    
   if (power_signal_sell >= _level_signal_to_trade)
   {  
        if (input_price_sell == 0) get_price_sell();                     
        return true; // собственно вот комманда к действию
   }
  //---------------------------------// }
  input_price_sell = 0;  
  refresh          = false;
  return false;
}  

//////////////////////////////////////  
// сигнал на покупку                //
//////////////////////////////////////
bool signal_buy(double ma14_1, double ma14_2, double ma14_3, double ma26_1, double ma26_2, double ma26_3)
{
  if (disable_signal_buy == 1) 
  {
   input_price_buy = 0;
   return false;
  } 
  double spread = abs(Ask-Bid);
 
   if ( (
         (ma26_1 < ma14_1 && ma26_2 > ma14_2) || 
         (ma26_2 < ma14_2 && ma26_3 > ma14_3) ||
         (ma26_1 < ma14_1 && ma26_3 > ma14_3)
        ) && Ask > ma14_1
      ) 
    {
     if (input_price_buy == 0) {
        input_price_buy = Ask - ShiftInputPoint*Point;
        _TakeProffit    = TakeProffit;
        _StopLoss       = StopLoss;
       } return true;}
   if (
      (Open[2] < ma14_2 - spread && Close[2] > ma14_2 + spread) &&
      (Open[1] > ma14_1 + spread && Close[1] > ma14_1 + spread) && 
      Ask > ma14_1
      )
   { if (input_price_buy == 0) 
       {
        input_price_buy = Ask - ShiftInputPoint*Point;
        _TakeProffit    = TakeProffit;
        _StopLoss       = StopLoss;
       } return true;}   
           
  input_price_buy = 0;  
  _TakeProffit    = TakeProffit;
  _StopLoss       = StopLoss;
  return false;
} 
  
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {            
   //--- get Moving Average 
   int daPeriod[10];
   daPeriod[00] = PERIOD_CURRENT;
   daPeriod[01] = PERIOD_M1;
   daPeriod[02] = PERIOD_M5;
   daPeriod[03] = PERIOD_M15;
   daPeriod[04] = PERIOD_M30;
   daPeriod[05] = PERIOD_H1;
   daPeriod[06] = PERIOD_H4;
   daPeriod[07] = PERIOD_D1;
   daPeriod[08] = PERIOD_W1;
   daPeriod[09] = PERIOD_MN1;
   int yind = 1;
   SUMM_SIGNAL = 0;
   sPeriod = daPeriod[yind];
   //--- RSI Analize Trend
   sum_index_ac  = 0;
   sum_index_rsi = 0;
   count_for_avg = 0;
   //--- End  RSI Analize Trend
   while (sPeriod < PERIOD_MN1 && !IsStopped() && yind < 10)
   {
     sPeriod = daPeriod[yind]; yind++;
     if (Period() != sPeriod)
     {
      count_for_avg++;
      //-- RSI Analize trend
      depth_trend();
      speed_ac();
      //-- End RSI Analize trend     
      double ma1 = iMA(NULL,sPeriod, MovingPeriod_m1, 1, MODE_SMA, PRICE_CLOSE, 0);
      double ma2 = iMA(NULL,sPeriod, MovingPeriod_m1, 2, MODE_SMA, PRICE_CLOSE, 0);
      double ma3 = iMA(NULL,sPeriod, MovingPeriod_m1, 3, MODE_SMA, PRICE_CLOSE, 0);      
      double ma4 = iMA(NULL,sPeriod, MovingPeriod_m2, 1, MODE_SMA, PRICE_CLOSE, 0);
      double ma5 = iMA(NULL,sPeriod, MovingPeriod_m2, 2, MODE_SMA, PRICE_CLOSE, 0);
      double ma6 = iMA(NULL,sPeriod, MovingPeriod_m2, 3, MODE_SMA, PRICE_CLOSE, 0);   
      refresh = true;
      if (signal_sell(ma1, ma2, ma3, ma4, ma5, ma6)) {refresh = false;}       
     } 
   }
   sPeriod = Period();
   ma1 = iMA(NULL,sPeriod, MovingPeriod_m1, 1, MODE_SMA, PRICE_CLOSE, 0);
   ma2 = iMA(NULL,sPeriod, MovingPeriod_m1, 2, MODE_SMA, PRICE_CLOSE, 0);
   ma3 = iMA(NULL,sPeriod, MovingPeriod_m1, 3, MODE_SMA, PRICE_CLOSE, 0);      
   ma4 = iMA(NULL,sPeriod, MovingPeriod_m2, 1, MODE_SMA, PRICE_CLOSE, 0);
   ma5 = iMA(NULL,sPeriod, MovingPeriod_m2, 2, MODE_SMA, PRICE_CLOSE, 0);
   ma6 = iMA(NULL,sPeriod, MovingPeriod_m2, 3, MODE_SMA, PRICE_CLOSE, 0);  
   int val_index_close = iLowest(NULL, sPeriod, MODE_CLOSE, 10, 0); 
   int val_index_open  = iLowest(NULL, sPeriod, MODE_OPEN,  10, 0); 
   int val_index_low   = iLowest(NULL, sPeriod, MODE_LOW,   10, 0); 
   int val_index_high  = iLowest(NULL, sPeriod, MODE_HIGH,  10, 0); 
   if (fmod(Volume[0], tiks_for_refresh) == 0) {refresh = true;}
   //-- RSI Analize trend
   depth_trend();
   speed_ac();
   //-- End RSI Analize trend   
//--- sell conditions
   if (
       signal_sell(ma1, ma2, ma3, ma4, ma5, ma6) && (SUMM_SIGNAL/count_for_avg>_level_avg_signal_to_trade)
      )
     {
      if (refresh) {
        Print("*** abs(input_price_sell-Bid): ", abs(input_price_sell-Bid), " ***");
        Print("*** Sensivity*Point: ", Sensivity*Point, " ***");
        }
      double spred = abs(Bid-Ask);
      if ((abs(input_price_sell-Bid) < Sensivity*Point + spred) && (input_price_sell > 0))
      {
       Print("SELL SELL SELL");
       if (OrdersTotal() > LotCount-1) {} 
       else
       {
        int    res;  
        res = OrderSend(Symbol(), OP_SELL, LotsOptimized(),Bid,30,Bid+_StopLoss*Point,Bid-Point*_TakeProffit,"LIVE-EXPERT-VHE-AUTO-TRADE",MAGICMA,0,Red);
       } 
      } 
      if (refresh) refresh = false;
      return;
     }
//--- buy conditions
   if (
       signal_buy(ma1, ma2, ma3, ma4, ma5, ma6)
      )
     {
      spred = abs(Bid-Ask);
      if (abs(input_price_buy-Ask) < Sensivity*Point + spred)
      {
       if (OrdersTotal() > LotCount-1) {} 
       else
       {
        res = OrderSend(Symbol(), OP_BUY, LotsOptimized(),Ask,3,Ask-_StopLoss*Point,Ask+Point*_TakeProffit,"LIVE-EXPERT-VHE-AUTO-TRADE",MAGICMA,0,Blue);
       } 
      } 
      if (refresh) refresh = false;
      return;
     }
//---
  if (refresh) refresh = false;
  }


//*********************************************//
// Сохраняем информацию о открытых ордерах  ***//
//*********************************************//  
void OnOrderOpenOrModify()
{ 
if (fmod(Volume[0], tiks_for_refresh) == 0) {refresh = true;}  
//-- Сохраняем информацию о открытых ордерах ------// 
 string file_name = orders_file_name;
 if (IsTesting())
 {
   file_name = orders_file_name_tester;
 } 
 if (refresh) SaveOpenOrders(file_name);  
//-------------------------------------------------// 
 }
   
//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {

OnOrderOpenOrModify();
int total=OrdersTotal();
  
//---
if (close_all_openorders) {

Print("BID-ASK", abs(MarketInfo(OrderSymbol(),MODE_BID) - MarketInfo(OrderSymbol(),MODE_ASK)));

int mb = MessageBox("Вы действительно хотите закрыть все ордера?", "Сообщение", MB_OKCANCEL); }
if (mb == IDOK)
{
  for(int cnt1=0;cnt1<total;cnt1++)
     {
       if(!OrderSelect(cnt1,SELECT_BY_POS,MODE_TRADES))
         continue;
       if(OrderType()==OP_BUY)
       {  
        
        if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_BID), abs(Bid-Ask)+10, clrGreen))
         {
           Print("OrderClose error ",GetLastError());
           continue;  
         }
       } else
       {
        if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(),MODE_ASK), abs(Bid-Ask)+10, clrAqua))
        {
         Print("OrderClose error ",GetLastError());
         continue;  
        } 
       } 
     }
 close_all_openorders = false;    
} else
{
 close_all_openorders = false;
}


//--- it is important to enter the market correctly, but it is more important to exit it correctly...   
   for(int cnt=0;cnt<total;cnt++)
     {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         continue;
                        
      if(OrderType()<=OP_SELL &&   // check for opened position 
         OrderSymbol()==Symbol())  // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_BUY)
           {
            if (RiskOffPoint         > 0 && 
                Bid-OrderOpenPrice() > Point*RiskOffPoint)
            {              
              if (OrderStopLoss()<Bid-Point*5 && OrderOpenPrice() > OrderStopLoss())
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice()+Point*5,OrderTakeProfit(),0,Green))
                  Print("OrderModify error ",GetLastError());
                return;
              }       
            }
           /////////////////////////////////////////////   
           // Механизм продвинутого трайлинг стопа   
           /////////////////////////////////////////////
            if ( OrderStopLoss()          < Low[1] && 
                 Low[1] -OrderOpenPrice() > Point*RiskOffPoint &&
                 RiskOffPoint       > 0)
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), Low[1],OrderTakeProfit(),0,Green))
                  Print("OrderModify error ",GetLastError());
                return;
              }
           ////////////////////////////////////////////////
             
            //--- check for trailing stop
            if(TrailingStop>0 && disable_trailing == 0)
              {
               if(Bid-OrderOpenPrice()>Point*TrailingStop &&
                  Bid-OrderOpenPrice()>Point*RiskOffPoint)
                 {
                  if(OrderStopLoss()<Bid-Point*TrailingStop*2)
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,OrderTakeProfit(),0,Green))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
         else // go to short position
           {          
            if (RiskOffPoint         > 0 && 
                OrderOpenPrice()-Ask > Point*RiskOffPoint)
            {
              if(OrderStopLoss()>Ask+Point*5 && OrderOpenPrice() < OrderStopLoss())
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), OrderOpenPrice()-Point*5,OrderTakeProfit(),0,Red))
                  Print("OrderModify error ",GetLastError());
                return;
              }     
           
           /////////////////////////////////////////////   
           // Механизм продвинутого трайлинг стопа   
           /////////////////////////////////////////////
              if(OrderStopLoss()>High[1] && 
                 OrderOpenPrice()-High[1] > Point*RiskOffPoint &&
                 RiskOffPoint       > 0)
              {
                if(!OrderModify(OrderTicket(),OrderOpenPrice(), High[1], OrderTakeProfit(), 0, Red))
                  Print("OrderModify error ",GetLastError());
                return;
              }                
            } 
          ////////////////////////////////////////////////
            
            //--- check for trailing stop
            if(TrailingStop>0 && disable_trailing == 0)
              {
               if((OrderOpenPrice()-Ask)>(Point*TrailingStop) &&
                  (OrderOpenPrice()-Ask)>(Point*RiskOffPoint) 
                 )
                 {
                  if((OrderStopLoss()>(Ask+Point*TrailingStop*2)) || (OrderStopLoss()==0))
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit(),0,Red))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//-- собственно здесь все просто: 
//-- сначала функция открывающая ордера если есть на то сигнал
   CheckForOpen();
//-- затем функция сопровождающая сделки по уже открытым ордерам   
   CheckForClose();   
//---
//   if (OrdersHistoryTotal() > history_count) 
// Процедура OnOrderClose определяет был ли какой нибудь ордер закрыт 
   OnOrderClose();
  }
//+------------------------------------------------------------------+

void OnOrderClose()
{
 // -- мы запоминали в массив открытые позиции и номер тикета
 // -- по этим данным мы легко можем определить
 // -- если хотя бы один ордер был закрыт или удален
 // -- и стереть данные из соотв ячейки массива в таком случае
 for(int y=0;y<len_array_op_points;y++)
  {
    if (_Array_open_ticket[y] > 0) 
    {
      if (OrderSelect(_Array_open_ticket[y], SELECT_BY_TICKET))
      {
      // Только закрытые ордера имеют время закрытия, не равное 0. Открытые или отложенные ордера имеют время закрытия, равное 0.
        if (OrderCloseTime() > 0)
         { 
           // момент когда мы определили что ордер с тикет номером (_Array_open_ticket[y]) был закрыт
           SaveOrderByTicket(orders_close_file_name, _Array_open_ticket[y]);
           _Array_open_points[y]  = 0; 
           _Array_open_ticket[y]  = 0;
         }  
      }  
    }  
  }
}

void OnInit()
{
 close_all_openorders      = closeallorders;
 if (sPeriod != Period())
 {
   refresh = true;
 }
 sPeriod                   = Period();
 // -- проверка правильности инициализации переменных
 if (level_avg_signal_to_trade > 10) _level_avg_signal_to_trade = 10;
 if (level_avg_signal_to_trade < 1)  _level_avg_signal_to_trade = 1;
 
 if (level_signal_to_trade > 11) _level_signal_to_trade = 11;
 if (level_signal_to_trade < 4)  _level_signal_to_trade = 4;
 // очистка массива в котором запоминаем до 10 точек в которых открывались ордера
 // содержит примерное значение (так как есть такая штука как проскальзывание)
 for(int y=0;y<len_array_op_points;y++)
 {
 _Array_open_points[y]  = 0; 
 }
 //
 history_count = OrdersHistoryTotal();
}
