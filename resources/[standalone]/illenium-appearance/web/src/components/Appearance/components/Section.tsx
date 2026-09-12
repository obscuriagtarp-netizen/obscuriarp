import { ReactNode } from 'react';
import styled from 'styled-components';

interface SectionProps {
  title: string;
  deps?: any[];
  children?: ReactNode;
}

const Container = styled.div`
  width: 100%;

  display: flex;
  flex-direction: column;

  color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 1);

  user-select: none;

  gap: 13px;
`;

const Header = styled.div`
  width: 100%;
  min-height: 57px;

  display: flex;
  align-items: center;
  justify-content: space-between;

  padding: 0 4px 13px;
  border-bottom: 1px solid rgba(176, 125, 203, .2);

  z-index: 2;

  span {
    font-family: Georgia, 'Times New Roman', serif;
    font-size: 24px;
    font-weight: 500;
  }

  @media (max-height: 820px) {
    min-height: 46px;
    padding-bottom: 9px;

    span { font-size: 21px; }
  }
`;

const Items = styled.div`
  padding-bottom: 5px;
`;

const Section: React.FC<SectionProps> = ({ children, title, deps = [] }) => {
  return (
    <Container>
      <Header>
        <span>{title}</span>
      </Header>
      <Items>{children}</Items>
    </Container>
  );
};

export default Section;
