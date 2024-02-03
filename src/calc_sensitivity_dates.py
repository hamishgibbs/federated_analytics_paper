import pandas as pd
import numpy as np
from pandas.tseries.holiday import USFederalHolidayCalendar

def sensitivity_dates():
    """
    Generates a list of dates containing the first week of each month and US federal holidays outside these dates.
    """
    
    months = pd.date_range(start="2019-01-01", end="2019-12-31", freq='MS')
    first_week_dates = [pd.date_range(start=month, periods=7, freq='D') for month in months]
    first_week_dates = np.concatenate(first_week_dates)

    cal = USFederalHolidayCalendar()
    holidays = cal.holidays(start="2019-01-01", end="2019-12-31")
    holidays = holidays[~holidays.isin(first_week_dates)]  

    selected_dates = np.sort(np.concatenate([first_week_dates, holidays]))

    selected_dates_datetime = [pd.Timestamp(date).to_pydatetime() for date in selected_dates]

    return [date.strftime("%Y_%m_%d") for date in selected_dates_datetime]

