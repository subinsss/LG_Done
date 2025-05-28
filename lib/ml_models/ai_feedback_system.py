import pandas as pd
import numpy as np
import joblib
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class ProductivityFeedbackSystem:
    def __init__(self):
        """생산성 피드백 시스템 초기화"""
        self.model = None
        self.feature_names = None
        self.feature_importance = None
        self.load_model()
        
    def load_model(self):
        """저장된 모델과 특성 정보 로드"""
        try:
            # 모델 로드
            self.model = joblib.load('models/best_productivity_model.pkl')
            
            # 특성 이름과 중요도 로드
            model_info = joblib.load('models/model_info.pkl')
            self.feature_names = model_info['feature_names']
            self.feature_importance = model_info['feature_importance']
            
            print("✅ 모델 로드 완료!")
            
        except Exception as e:
            print(f"❌ 모델 로드 실패: {e}")
            return False
        return True
    
    def get_user_current_status(self, user_id, recent_days=7):
        """사용자의 최근 상태 분석"""
        # 시계열 데이터 로드
        df = pd.read_csv('productivity_data/timeseries_productivity_data.csv')
        
        # 해당 사용자의 최근 데이터 추출
        user_data = df[df['user_id'] == user_id].tail(recent_days)
        
        if len(user_data) == 0:
            return None
            
        # 최근 평균 계산
        current_status = {
            'work_hours': user_data['work_hours'].mean(),
            'exercise_minutes': user_data['exercise_minutes'].mean(),
            'sleep_hours': user_data['sleep_hours'].mean(),
            'leisure_hours': user_data['leisure_hours'].mean(),
            'screen_time_hours': user_data['screen_time_hours'].mean(),
            'commute_time_hours': user_data['commute_time_hours'].mean(),
            'productivity_score': user_data['productivity_score'].mean(),
            'age': user_data['age'].iloc[0]
        }
        
        return current_status
    
    def generate_improvement_scenarios(self, current_status):
        """개선 시나리오 생성"""
        scenarios = []
        base_features = self.prepare_features(current_status)
        base_prediction = self.model.predict([base_features])[0]
        
        # 1. 작업시간 조정 시나리오
        work_scenarios = [
            (current_status['work_hours'] + 1, "작업시간을 1시간 늘리면"),
            (current_status['work_hours'] + 0.5, "작업시간을 30분 늘리면"),
            (max(0, current_status['work_hours'] - 0.5), "작업시간을 30분 줄이면")
        ]
        
        for new_work_hours, description in work_scenarios:
            modified_status = current_status.copy()
            modified_status['work_hours'] = new_work_hours
            modified_features = self.prepare_features(modified_status)
            new_prediction = self.model.predict([modified_features])[0]
            improvement = new_prediction - base_prediction
            
            scenarios.append({
                'category': 'work_hours',
                'description': description,
                'current_value': current_status['work_hours'],
                'suggested_value': new_work_hours,
                'improvement': improvement,
                'new_score': new_prediction
            })
        
        # 2. 운동시간 조정 시나리오
        exercise_scenarios = [
            (current_status['exercise_minutes'] + 30, "운동시간을 30분 늘리면"),
            (current_status['exercise_minutes'] + 15, "운동시간을 15분 늘리면"),
            (max(0, current_status['exercise_minutes'] - 15), "운동시간을 15분 줄이면")
        ]
        
        for new_exercise, description in exercise_scenarios:
            modified_status = current_status.copy()
            modified_status['exercise_minutes'] = new_exercise
            modified_features = self.prepare_features(modified_status)
            new_prediction = self.model.predict([modified_features])[0]
            improvement = new_prediction - base_prediction
            
            scenarios.append({
                'category': 'exercise_minutes',
                'description': description,
                'current_value': current_status['exercise_minutes'],
                'suggested_value': new_exercise,
                'improvement': improvement,
                'new_score': new_prediction
            })
        
        # 3. 수면시간 조정 시나리오
        sleep_scenarios = [
            (min(10, current_status['sleep_hours'] + 0.5), "수면시간을 30분 늘리면"),
            (7.5, "수면시간을 7.5시간으로 맞추면"),
            (max(6, current_status['sleep_hours'] - 0.5), "수면시간을 30분 줄이면")
        ]
        
        for new_sleep, description in sleep_scenarios:
            modified_status = current_status.copy()
            modified_status['sleep_hours'] = new_sleep
            modified_features = self.prepare_features(modified_status)
            new_prediction = self.model.predict([modified_features])[0]
            improvement = new_prediction - base_prediction
            
            scenarios.append({
                'category': 'sleep_hours',
                'description': description,
                'current_value': current_status['sleep_hours'],
                'suggested_value': new_sleep,
                'improvement': improvement,
                'new_score': new_prediction
            })
        
        # 4. 스크린타임 조정 시나리오
        screen_scenarios = [
            (max(1, current_status['screen_time_hours'] - 1), "스크린타임을 1시간 줄이면"),
            (max(1, current_status['screen_time_hours'] - 0.5), "스크린타임을 30분 줄이면")
        ]
        
        for new_screen, description in screen_scenarios:
            modified_status = current_status.copy()
            modified_status['screen_time_hours'] = new_screen
            modified_features = self.prepare_features(modified_status)
            new_prediction = self.model.predict([modified_features])[0]
            improvement = new_prediction - base_prediction
            
            scenarios.append({
                'category': 'screen_time_hours',
                'description': description,
                'current_value': current_status['screen_time_hours'],
                'suggested_value': new_screen,
                'improvement': improvement,
                'new_score': new_prediction
            })
        
        return scenarios, base_prediction
    
    def prepare_features(self, status):
        """모델 입력용 특성 준비"""
        # 기본 특성
        features = [
            status['work_hours'],
            status['leisure_hours'], 
            status['exercise_minutes'],
            status['sleep_hours'],
            status['screen_time_hours'],
            status['commute_time_hours'],
            status['age']
        ]
        
        # 엔지니어링된 특성들 (complete_ml_analysis.py와 동일하게)
        total_active_time = status['work_hours'] + status['exercise_minutes']/60
        work_life_balance = status['leisure_hours'] / (status['work_hours'] + 0.1)
        sleep_quality = 1 - abs(status['sleep_hours'] - 7.5) / 7.5
        
        features.extend([
            total_active_time,
            work_life_balance, 
            sleep_quality
        ])
        
        return features
    
    def generate_feedback_text(self, scenarios, base_prediction, user_name="사용자"):
        """자연어 피드백 생성"""
        # 가장 효과적인 개선 방안 찾기
        positive_scenarios = [s for s in scenarios if s['improvement'] > 0]
        positive_scenarios.sort(key=lambda x: x['improvement'], reverse=True)
        
        feedback_text = f"""
🎯 {user_name}님의 생산성 분석 리포트
{'='*50}

📊 현재 상태:
• 예상 생산성 점수: {base_prediction:.1f}점
• 분석 기준: 최근 7일 평균

🚀 개선 추천사항:
"""
        
        if len(positive_scenarios) > 0:
            # 상위 3개 추천사항
            for i, scenario in enumerate(positive_scenarios[:3], 1):
                improvement_percent = (scenario['improvement'] / base_prediction) * 100
                
                if scenario['category'] == 'work_hours':
                    unit = "시간"
                    current_val = f"{scenario['current_value']:.1f}"
                    suggested_val = f"{scenario['suggested_value']:.1f}"
                elif scenario['category'] == 'exercise_minutes':
                    unit = "분"
                    current_val = f"{scenario['current_value']:.0f}"
                    suggested_val = f"{scenario['suggested_value']:.0f}"
                elif scenario['category'] == 'sleep_hours':
                    unit = "시간"
                    current_val = f"{scenario['current_value']:.1f}"
                    suggested_val = f"{scenario['suggested_value']:.1f}"
                else:
                    unit = "시간"
                    current_val = f"{scenario['current_value']:.1f}"
                    suggested_val = f"{scenario['suggested_value']:.1f}"
                
                feedback_text += f"""
{i}. {scenario['description']}
   현재: {current_val}{unit} → 권장: {suggested_val}{unit}
   예상 효과: +{scenario['improvement']:.1f}점 ({improvement_percent:+.1f}%)
   예상 생산성: {scenario['new_score']:.1f}점
"""
        
        # 특성 중요도 기반 일반적 조언
        feedback_text += f"""

💡 일반적인 생산성 향상 팁:
• 꾸준한 운동은 생산성에 가장 큰 영향을 미칩니다
• 적절한 작업시간 배분이 중요합니다 (6-8시간 권장)
• 7-8시간의 충분한 수면을 취하세요
• 스크린타임을 줄이고 여가시간을 늘려보세요

📅 내일 실천해보세요:
"""
        
        if len(positive_scenarios) > 0:
            best_scenario = positive_scenarios[0]
            if best_scenario['category'] == 'work_hours':
                feedback_text += f"• 작업시간을 {best_scenario['suggested_value']:.1f}시간으로 조정\n"
            elif best_scenario['category'] == 'exercise_minutes':
                feedback_text += f"• 운동시간을 {best_scenario['suggested_value']:.0f}분으로 늘리기\n"
            elif best_scenario['category'] == 'sleep_hours':
                feedback_text += f"• 수면시간을 {best_scenario['suggested_value']:.1f}시간으로 맞추기\n"
            elif best_scenario['category'] == 'screen_time_hours':
                feedback_text += f"• 스크린타임을 {best_scenario['suggested_value']:.1f}시간으로 줄이기\n"
        
        feedback_text += "\n🌟 작은 변화가 큰 차이를 만듭니다!"
        
        return feedback_text
    
    def get_personalized_feedback(self, user_id, user_name="사용자"):
        """개인화된 피드백 생성 (메인 함수)"""
        # 1. 사용자 현재 상태 분석
        current_status = self.get_user_current_status(user_id)
        
        if current_status is None:
            return "❌ 해당 사용자의 데이터를 찾을 수 없습니다."
        
        # 2. 개선 시나리오 생성
        scenarios, base_prediction = self.generate_improvement_scenarios(current_status)
        
        # 3. 자연어 피드백 생성
        feedback = self.generate_feedback_text(scenarios, base_prediction, user_name)
        
        return feedback

def main():
    """피드백 시스템 테스트"""
    print("🤖 AI 생산성 피드백 시스템")
    print("=" * 60)
    
    # 피드백 시스템 초기화
    feedback_system = ProductivityFeedbackSystem()
    
    # 테스트용 사용자들
    test_users = [1, 25, 50, 75]
    user_names = ["김철수", "이영희", "박민수", "최지영"]
    
    for user_id, user_name in zip(test_users, user_names):
        print(f"\n{'='*60}")
        feedback = feedback_system.get_personalized_feedback(user_id, user_name)
        print(feedback)
        print("\n" + "="*60)
        
        # 사용자 입력 대기
        input("다음 사용자 피드백을 보려면 Enter를 누르세요...")

if __name__ == "__main__":
    main() 