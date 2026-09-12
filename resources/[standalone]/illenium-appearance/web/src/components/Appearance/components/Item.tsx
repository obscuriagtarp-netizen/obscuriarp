import styled from 'styled-components';
import { ReactNode } from 'react';

interface ItemProps {
  title?: string;
  children?: ReactNode;
  columns?: 1 | 2;
}

const Container = styled.div`
  margin-top: 11px;

  display: flex;
  flex-direction: column;

  padding: 16px;
  border-radius: 4px;

  background: rgba(255,255,255,.024);
  border: 1px solid rgba(255,255,255,.07);

  > span {
    color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 1);
    font-size: 13px;
    font-weight: 700;
    text-transform: uppercase;
    color: #b9afbf;
  }
`;

const Inputs = styled.div<{ $columns: 1 | 2 }>`
  width: 100%;
  display: grid;
  grid-template-columns: repeat(${props => props.$columns}, minmax(0, 1fr));
  align-items: start;
  gap: 15px 14px;
  margin-top: 13px;

  > * {
    min-width: 0;
    margin: 0 !important;
  }

  ${props => props.$columns === 2 && `
    > :last-child:nth-child(odd) { grid-column: 1 / -1; }
  `}

  @media (max-width: 1180px) {
    grid-template-columns: minmax(0, 1fr);
    > :last-child:nth-child(odd) { grid-column: auto; }
  }
`;

const Item: React.FC<ItemProps> = ({ children, title, columns = 2 }) => {
  return (
    <Container>
      {title && <span>{title}</span>}
      <Inputs $columns={columns}>{children}</Inputs>
    </Container>
  );
};

export default Item;
